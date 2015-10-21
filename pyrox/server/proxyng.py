import socket

import tornado
import tornado.ioloop
import tornado.process

from .routing import RoundRobinRouter, PROTOCOL_HTTP, PROTOCOL_HTTPS

from pyrox.tstream.iostream import (SSLSocketIOHandler, SocketIOHandler,
                                    StreamClosedError)
from pyrox.tstream.tcpserver import TCPServer

from pyrox.log import get_logger
from pyrox.about import VERSION
from pyrox.http import (HttpRequest, HttpResponse, RequestParser,
                        ResponseParser, ParserDelegate)
import traceback
import functools

_LOG = get_logger(__name__)

_SERVER = 'pyrox/{}'.format(VERSION)

"""
100 Continue intermediate response
"""
_100_CONTINUE = b'HTTP/1.1 100 Continue\r\n\r\n'


"""
CONNECT OK response to client
"""
_CONNECT_OK = b'HTTP/{version} 200 Connection established\r\n\r\n'


"""
String representing a 0 length HTTP chunked encoding chunk.
"""
_CHUNK_CLOSE = b'0\r\n\r\n'


"""
Default return object on error. This should be configurable.
"""
_BAD_GATEWAY_RESP = HttpResponse()
_BAD_GATEWAY_RESP.version = b'1.1'
_BAD_GATEWAY_RESP.status = '502 Bad Gateway'
_BAD_GATEWAY_RESP.headers['Server'].append(_SERVER)
_BAD_GATEWAY_RESP.headers['Content-Length'] = 0

"""
Default return object on no route or upstream not responding. This should
be configurable.
"""
_UPSTREAM_UNAVAILABLE = HttpResponse()
_UPSTREAM_UNAVAILABLE.version = b'1.1'
_UPSTREAM_UNAVAILABLE.status = '503 Service Unavailable'
_UPSTREAM_UNAVAILABLE.headers['Server'].append(_SERVER)
_UPSTREAM_UNAVAILABLE.headers['Content-Length'] = 0

_MAX_CHUNK_SIZE = 16384


def _write_chunk_to_stream(stream, data, callback=None):
    # Format and write this chunk
    chunk = bytearray()
    chunk.extend(hex(len(data))[2:])
    chunk.extend('\r\n')
    chunk.extend(data)
    chunk.extend('\r\n')

    stream.write(chunk, callback)


def _write_to_stream(stream, data, is_chunked, callback=None):
    if is_chunked:
        _write_chunk_to_stream(stream, data, callback)
    else:
        stream.write(data, callback)


class AccumulationStream(object):

    def __init__(self):
        self.data = None
        self.reset()

    def reset(self):
        self.data = bytearray()

    def write(self, data, callback=None):
        self.data.extend(data)
        if callback:
            callback()

    def size(self):
        return len(self.data)


class ProxyHandler(ParserDelegate):
    """
    Common class for the stream handlers. This parent class manages the
    following:

    - Handling of header field names.
    - Tracking rejection of message sessions.
    """

    def __init__(self, filter_pl, http_msg):
        self._filter_pl = filter_pl
        self._http_msg = http_msg
        self._expect = None
        self._chunked = False
        self._last_header_field = None
        self._intercepted = False
        self._rerouted = False
        self._keep_alive = False

    def on_http_version(self, major, minor):
        self._http_msg.version = '{}.{}'.format(major, minor)

    def on_header_field(self, field):
        self._last_header_field = field

    def on_header_value(self, value):
        header = self._http_msg.header(self._last_header_field)
        header.values.append(value)

        # This is useful for handling 100 continue situations
        if self._last_header_field.lower() == 'expect':
            self._expect = value.lower()

        self._last_header_field = None


class DownstreamHandler(ProxyHandler):
    """
    This proxy handler manages data coming from downstream of the proxy.
    This data comes from the client initiating the request against the
    proxy.
    """

    def __init__(self, downstream, downstream_address, filter_pl, connect_upstream):
        super(DownstreamHandler, self).__init__(filter_pl, HttpRequest())
        self._accumulator = AccumulationStream()
        self._preread_body = AccumulationStream()

        self._downstream = downstream
        self._http_msg.client_address = downstream_address

        self._upstream = None
        self._connect_upstream = connect_upstream

    def on_req_method(self, method):
        self._http_msg.method = method

    def on_req_path(self, url):
        self._http_msg.url = url

    def on_headers_complete(self):
        # Execute against the pipeline
        action = self._filter_pl.on_request_head(self._http_msg)

        # Make sure we handle 100 continue
        if self._expect is not None and self._expect == '100-continue':
            self._downstream.write(_100_CONTINUE)

        # If we are intercepting the request body do some negotiation
        if self._filter_pl.intercepts_req_body():
            self._chunked = True

            # If there's a content length, negotiate the transfer encoding
            if self._http_msg.get_header('content-length'):
                self._http_msg.remove_header('content-length')

                self._http_msg.replace_header(
                    'transfer-encoding').values.append('chunked')

        # If we're rejecting then we're not going to connect to upstream
        if not action.should_connect_upstream():
            self._intercepted = True
            self._response_tuple = action.payload
        else:
            # Hold up on the client side until we're done negotiating
            # connections.
            self._downstream.handle.disable_reading()

            # We're routing to upstream; we need to know where to go
            if action.is_routing():
                self._connect_upstream(self._http_msg, action.payload)
            else:
                self._connect_upstream(self._http_msg)

    def on_body(self, chunk, length, is_chunked):
        # Rejections simply discard the body
        if self._intercepted or self._rerouted:
            return

        # Hold up on the client side until we're done with this chunk
        self._downstream.handle.disable_reading()

        # Run through the filter PL and see if we need to modify
        # the body
        self._accumulator.reset()
        action = self._filter_pl.on_request_body(chunk, self._accumulator, self._http_msg)

        # Check to see if the filter modified the body
        if self._accumulator.size():
            chunk = self._accumulator.data

        # Rerouting to a new upstream
        if action.is_routing():
            return self.reroute(action.payload)

        elif self._upstream:
            # When we write to upstream set the callback to resume
            # reading from downstream.
            _write_to_stream(self._upstream,
                             chunk,
                             is_chunked,
                             self._downstream.handle.resume_reading)

        else:
            # If we're not connected upstream, store the fragment
            # for later. We will resume reading once upstream
            # connects
            self._preread_body.write(chunk)

    def reroute(self, route):
        _LOG.info("Rerouting to new upstream")
        # self._upstream.handle.disable_reading()
        self._rerouted = True
        return self._connect_upstream(self._http_msg, route)

    def on_upstream_connect(self, upstream):
        if self._upstream:
            # This is a new upstream
            _LOG.debug("Replacement upstream: %s", upstream)
        self._upstream = upstream

        if self._http_msg.method == 'CONNECT':
            # Connect downstream read to upstream write
            self._downstream.read(self._upstream.write)

            # Signal to downstream that the tunnel is ready
            self._downstream.write(
                _CONNECT_OK.format(version=self._http_msg.version),
                self._downstream.handle.resume_reading,
            )

        elif self._preread_body.size() > 0:
            self._downstream.handle.disable_reading()
            _write_to_stream(self._upstream,
                             self._preread_body.data,
                             self._chunked,
                             self._downstream.handle.resume_reading)

            # Empty the object
            self._preread_body.reset()

        else:
            self._downstream.handle.resume_reading()

    def on_message_complete(self, is_chunked, keep_alive):
        self._keep_alive = bool(keep_alive)

        self._downstream.handle.disable_reading()
        callback = self.complete

        if self._intercepted:
            # Commit the response to the client (aka downstream)
            writer = ResponseWriter(
                self._response_tuple[0],
                self._response_tuple[1],
                self._downstream,
                callback)

            writer.commit()

        elif is_chunked:
            # Finish the body with the closing chunk for the origin server
            self._upstream.write(_CHUNK_CLOSE, callback)

        else:
            callback()

    def complete(self):
        if self._keep_alive:
            # Clean up the message obj
            self._http_msg = HttpRequest()

            self._downstream.handle.resume_reading()

        else:
            # We're done here - close up shop
            self._downstream.close()


class ResponseWriter(object):
    def __init__(self, response, source, stream, on_complete):
        self._on_complete = on_complete
        self._response = response
        self._source = source
        self._stream = stream
        self._written = 0

    def commit(self):
        self.write_head()

    def write_head(self):
        if self._source is not None:
            if self._response.get_header('content-length'):
                self._response.remove_header('content-length')

            # Set to chunked to make the transfer easier
            self._response.replace_header('transfer-encoding').values.append('chunked')

        self._stream.write(self._response.to_bytes(), self.write_body)

    def write_body(self):
        if self._source is None:
            self._on_complete()
            return

        src_type = type(self._source)

        if src_type is bytearray or src_type is bytes or src_type is str:
            self.write_body_as_array()

        elif src_type is file:
            self.write_body_as_file()

        else:
            raise TypeError(
                'Unable to use {} as response body'.format(src_type))

    def write_body_as_file(self):
        next_chunk = self._source.read(_MAX_CHUNK_SIZE)

        if len(next_chunk) == 0:
            self._stream.write(_CHUNK_CLOSE, self._on_complete)
        else:
            _write_chunk_to_stream(
                self._stream,
                next_chunk,
                self.write_body_as_file)

    def write_body_as_array(self):
        src_len = len(self._source)

        if self._written == src_len:
            self._stream.write(_CHUNK_CLOSE, self._on_complete)
        else:
            max_idx = self._written + _MAX_CHUNK_SIZE
            limit_idx = max_idx if max_idx < src_len else src_len

            next_chunk = self._source[self._written:limit_idx]
            self._written = limit_idx

            _write_chunk_to_stream(
                self._stream,
                next_chunk,
                self.write_body_as_array)


class PeekAccumulationStream(AccumulationStream):
    peek_size = 0
    peeking = True

    def __init__(self, backend_stream, size=None):
        super(PeekAccumulationStream, self).__init__()
        self.backend_stream = backend_stream
        if size is not None:
            self.peek_size = size
        if self.peek_size == 0:
            self.peeking = False

    def write(self, chunk, callback=None):
        if not self.peeking:
            return self.backend_stream.write(chunk, callback=callback)
        cb = functools.partial(self.maybe_flush, callback=callback)
        return super(PeekAccumulationStream, self).write(chunk, cb)

    def full(self):
        return self.size() > self.peek_size

    def _maybe_callback(self, callback):
        if callback:
            return callback()

    def maybe_flush(self, callback=None):
        if self.peeking and self.full():
            return self.flush(callback=callback)
        else:
            return self._maybe_callback(callback)

    def flush(self, callback=None):
        if not self.peeking:
            return self._maybe_callback(callback)

        self.peeking = False
        self.backend_stream.write(self.data, callback=callback)
        self.reset()

    def __getattr__(self, item):
        return getattr(self.backend_stream, item)


class UpstreamHandler(ProxyHandler):
    """
    This proxy handler manages data coming from upstream of the proxy. This
    data usually comes from the origin service or it may come from another
    proxy.
    """
    _peek_downstream = None

    def __init__(self, downstream, upstream, filter_pl, request, connect_upstream):
        super(UpstreamHandler, self).__init__(filter_pl, HttpResponse())
        self._downstream = downstream
        self._upstream = upstream
        self._request = request
        self._connect_upstream = connect_upstream

    def on_status(self, status_code):
        self._http_msg.status = str(status_code)

    def on_headers_complete(self):
        action = self._filter_pl.on_response_head(self._http_msg, self._request)

        # Rerouting to a new upstream
        if action.is_routing():
            return self.reroute(action.payload)

        # If we are intercepting the response body do some negotiation
        if self._filter_pl.intercepts_resp_body():

            # If there's a content length, negotiate the transfer encoding
            if self._http_msg.get_header('content-length'):
                self._chunked = True
                self._http_msg.remove_header('content-length')

                self._http_msg.replace_header(
                    'transfer-encoding').values.append('chunked')

        if action.is_rejecting():
            self._intercepted = True
            self._response_tuple = action.payload
            return

        if self._request.peek_size:
            # Specified somewhere in request actions
            self._http_msg.peek_size = self._request.peek_size

        if self._http_msg.peek_size:
            _LOG.info("Peeking response size=%s", self._http_msg.peek_size)
            # Wrap downstream with a set-size buffered stream
        self._peek_downstream = PeekAccumulationStream(self._downstream, size=self._http_msg.peek_size)

        data = self._http_msg.to_bytes()
        self._peek_downstream.write(data)

    def reroute(self, route):
        self._rerouted = True
        self._connect_upstream(self._request, route)

    def on_body(self, data, length, is_chunked):
        # Rejections simply discard the body
        if self._intercepted or self._rerouted:
            return

        accumulator = AccumulationStream()

        action = self._filter_pl.on_response_body(data, accumulator, self._http_msg, self._request)

        if accumulator.size() > 0:
            data = accumulator.data

        if self._request.peek_size and self._peek_downstream.peeking:
            # Rerouting to a new upstream
            if action.is_routing():
                _LOG.error("Rerouting")
                self.reroute(action.payload)
                return

            # Rejecting
            # Only applicable if we haven't sent any data yet.
            elif action.is_rejecting():
                _LOG.error("Rejecting")
                self._intercepted = True
                self._response_tuple = action.payload
                return

        # Hold up on the upstream side until we're done sending this chunk
        self._upstream.handle.disable_reading()

        # When we write to the stream set the callback to resume
        # reading from upstream.
        _write_to_stream(
            self._peek_downstream,
            data,
            is_chunked or self._chunked,
            self._upstream.handle.resume_reading)

    def on_message_complete(self, is_chunked, keep_alive):
        self._upstream.handle.disable_reading()

        if keep_alive:
            callback = self._downstream.handle.resume_reading
            self._http_msg = HttpResponse()
        else:
            callback = self._upstream.close

        ''' Callbacks are now set '''

        if self._rerouted:
            callback()
            return

        if self._intercepted:
            # Serialize our message to them
            # Commit the response to the client (aka downstream)
            writer = ResponseWriter(
                self._response_tuple[0],
                self._response_tuple[1],
                self._downstream,
                callback,
            )
            writer.commit()
            return

        if self._peek_downstream.peeking:
            callback = functools.partial(self._peek_downstream.flush, callback=callback)

        if is_chunked or self._chunked:
            self._peek_downstream.write(_CHUNK_CLOSE, callback=callback)
        else:
            callback()


class ConnectionTracker(object):

    def __init__(self, on_stream_live, on_target_closed, on_target_error):
        self._streams = dict()
        self._target_in_use = None
        self._on_stream_live = on_stream_live
        self._on_target_closed = on_target_closed
        self._on_target_error = on_target_error

    def destroy(self):
        for stream in self._streams.values():
            if not stream.closed():
                stream.close()

    def connect(self, target):
        self._target_in_use = target
        live_stream = self._streams.get(target)

        if live_stream:
            # Make the cb ourselves since the socket's already connected
            self._on_stream_live(live_stream)
        else:
            self._new_connection(target)

    def _new_connection(self, target):
        host, port, protocol = target

        # Set up our upstream socket
        us_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)

        # Create and bind the IO Handler based on selected protocol
        if protocol == PROTOCOL_HTTP:
            live_stream = SocketIOHandler(us_sock)
        elif protocol == PROTOCOL_HTTPS:
            live_stream = SSLSocketIOHandler(us_sock)
        else:
            raise Exception('Unknown protocol: {}.'.format(protocol))

        # Store the stream reference for later use
        self._streams[target] = live_stream

        # Build and set the on_close callback
        def on_close():
            # Disable error cb on close
            live_stream.on_error(None)

            del self._streams[target]
            if self._target_in_use == target:
                self.destroy()
                self._on_target_closed()
        live_stream.on_close(on_close)

        # Build and set the on_error callback
        def on_error(error):
            # Dsiable close cb on error
            live_stream.on_close(None)

            if self._target_in_use == target:
                del self._streams[target]
                if self._target_in_use == target:
                    self.destroy()
                    self._on_target_error(error)
        live_stream.on_error(on_error)

        # Build and set the on_connect callback and then connect
        def on_connect():
            self._on_stream_live(live_stream)
        live_stream.connect((host, port), on_connect)


class ProxyConnection(object):
    """
    A proxy connection manages the lifecycle of the sockets opened during a
    proxied client request against Pyrox.
    """
    def __init__(self, us_filter_pl, ds_filter_pl, downstream, downstream_address, router):
        self._ds_filter_pl = ds_filter_pl
        self._us_filter_pl = us_filter_pl
        self._router = router
        self._upstream_parser = None
        self._upstream_tracker = ConnectionTracker(
            self._on_upstream_live,
            self._on_upstream_close,
            self._on_upstream_error)

        # Setup all of the wiring for downstream
        self._downstream = downstream
        self._downstream_handler = DownstreamHandler(
            self._downstream,
            downstream_address,
            self._ds_filter_pl,
            self._connect_upstream)
        self._downstream_parser = RequestParser(self._downstream_handler)
        self._downstream.on_close(self._on_downstream_close)
        self._downstream.read(self._on_downstream_read)

    def _connect_upstream(self, request, route=None):
        if hasattr(self, '_request'):
            _LOG.info("Connecting to new upstream: %s", route)

        if route is not None:
            # This does some type checking for routes passed up via filter
            self._router.set_next(route)
        upstream_target = self._router.get_next(request)

        if upstream_target is None:
            _LOG.warning("Upstream target is None? request=%s", request)
            self._downstream.write(
                _UPSTREAM_UNAVAILABLE.to_bytes(),
                self._downstream.handle.resume_reading)
            return

        # Disable downstream reads
        self._downstream.handle.disable_reading()

        # Update the request to proxy upstream and store it
        # FUCK We can't do this as we're proxying, not reverse proxying
        # request.replace_header('host').values.append(
        #    '{}:{}'.format(upstream_target[0], upstream_target[1]))
        self._request = request

        try:
            self._upstream_tracker.connect(upstream_target)
        except Exception as ex:
            _LOG.exception(ex)

    def _on_upstream_live(self, upstream):
        self._upstream_handler = UpstreamHandler(
            self._downstream,
            upstream,
            self._us_filter_pl,
            self._request,
            self._connect_upstream)

        if self._upstream_parser:
            self._upstream_parser.destroy()
        self._upstream_parser = ResponseParser(self._upstream_handler)

        if self._request.method == 'CONNECT':
            # Connect upstream read to downstream write
            upstream.read(self._downstream.write)
        else:
            # Set the read callback
            upstream.read(self._on_upstream_read)

            # Send the proxied request object
            # If CONNECT, we don't send this upstream!
            # FUCK This is where we sent Content-Length: 0???
            upstream.write(self._request.to_bytes())

        # Set up our downstream handler
        self._downstream_handler.on_upstream_connect(upstream)

    def _on_downstream_close(self):
        self._upstream_tracker.destroy()
        self._downstream_parser.destroy()
        self._downstream_parser = None
        self._request = None

    def _on_downstream_error(self, error):
        _LOG.error('Downstream error: {}'.format(error))

        if not self._downstream.closed():
            self._downstream.close()

    def _on_upstream_error(self, error):
        _LOG.error('Upstream error: {}'.format(error))

        if not self._downstream.closed():
            self._downstream.write(_BAD_GATEWAY_RESP.to_bytes())

    def _on_upstream_close(self):
        _LOG.info('Upstream close')

        if not self._downstream.closed():
            _LOG.info('Closing downstream since upstream is closed')
            self._downstream.close()

        if self._upstream_parser is not None:
            self._upstream_parser.destroy()
            self._upstream_parser = None

    def _on_downstream_read(self, data):
        try:
            self._downstream_parser.execute(data)
        except StreamClosedError:
            pass
        except Exception as ex:
            _LOG.exception(ex)

    def _on_upstream_read(self, data):
        try:
            self._upstream_parser.execute(data)
        except StreamClosedError:
            pass
        except Exception as ex:
            _LOG.exception(ex)


class TornadoHttpProxy(TCPServer):
    """
    Subclass of the Tornado TCPServer that lets us set up the Pyrox proxy
    orchestrations.

    :param pipelines: This is a tuple with the upstream filter pipeline factory
                      as the first element and the downstream filter pipeline
                      factory as the second element.
    """
    def __init__(self, pipeline_factories, default_us_targets=None,
                 ssl_options=None):
        super(TornadoHttpProxy, self).__init__(ssl_options=ssl_options)
        self._router = RoundRobinRouter(default_us_targets)
        self.us_pipeline_factory = pipeline_factories[0]
        self.ds_pipeline_factory = pipeline_factories[1]

    def handle_stream(self, downstream, address):
        connection_handler = ProxyConnection(
            self.us_pipeline_factory(),
            self.ds_pipeline_factory(),
            downstream,
            address,
            self._router)
