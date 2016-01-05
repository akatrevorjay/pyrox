#cython: c_string_encoding=ascii  # for cython>=0.19
import os
import zlib
from  libcpp.string  cimport string as libcpp_string
from  libcpp.set     cimport set as libcpp_set
from  libcpp.vector  cimport vector as libcpp_vector
from  libcpp.pair    cimport pair as libcpp_pair
from  libcpp.map     cimport map  as libcpp_map
from  smart_ptr cimport shared_ptr
from  AutowrapRefHolder cimport AutowrapRefHolder
from  libcpp cimport bool
from  libc.string cimport const_char
from cython.operator cimport dereference as deref, preincrement as inc, address as address
from libc.stdlib cimport malloc, free
from libc.string cimport strlen
from cpython cimport bool, PyBytes_FromStringAndSize, PyBytes_FromString
from cpython.version cimport PY_MAJOR_VERSION

from pyrox.http._joyent_http_parser cimport http_cb
from pyrox.http._joyent_http_parser cimport http_data_cb
from pyrox.http._joyent_http_parser cimport flags as _flags
from pyrox.http._joyent_http_parser cimport http_errno as _http_errno
from pyrox.http._joyent_http_parser cimport http_method as _http_method
from pyrox.http._joyent_http_parser cimport http_parser_type as _http_parser_type
from pyrox.http._joyent_http_parser cimport http_parser_url_fields as _http_parser_url_fields
from pyrox.http._joyent_http_parser cimport HTTP_PARSER_ERRNO as _HTTP_PARSER_ERRNO_http_parser
from pyrox.http._joyent_http_parser cimport http_body_is_final as _http_body_is_final_http_parser
from pyrox.http._joyent_http_parser cimport http_errno_description as _http_errno_description_http_parser
from pyrox.http._joyent_http_parser cimport http_errno_name as _http_errno_name_http_parser
from pyrox.http._joyent_http_parser cimport http_method_str as _http_method_str_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_execute as _http_parser_execute_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_init as _http_parser_init_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_parse_url as _http_parser_parse_url_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_pause as _http_parser_pause_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_url_init as _http_parser_url_init_http_parser
from pyrox.http._joyent_http_parser cimport http_parser_version as _http_parser_version_http_parser
from pyrox.http._joyent_http_parser cimport http_should_keep_alive as _http_should_keep_alive_http_parser

cdef extern from "autowrap_tools.hpp":
    char *_cast_const_away(char *)

def http_errno_description(int err):
    assert err in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
                   28, 29, 30, 31], 'arg err wrong type'

    cdef char  *_r = _cast_const_away(_http_errno_description_http_parser((<_http_errno> err)))
    py_result = <char *> (_r)
    return py_result

def http_errno_name(int err):
    assert err in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
                   28, 29, 30, 31], 'arg err wrong type'

    cdef char  *_r = _cast_const_away(_http_errno_name_http_parser((<_http_errno> err)))
    py_result = <char *> (_r)
    return py_result

def http_method_str(int m):
    assert m in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
                 28, 29, 30, 31, 32], 'arg m wrong type'

    cdef char  *_r = _cast_const_away(_http_method_str_http_parser((<_http_method> m)))
    py_result = <char *> (_r)
    return py_result

def http_parser_version():
    cdef unsigned long int _r = _http_parser_version_http_parser()
    py_result = <unsigned long int> _r
    return py_result

cdef class http_method:
    HTTP_DELETE = 0
    HTTP_GET = 1
    HTTP_HEAD = 2
    HTTP_POST = 3
    HTTP_PUT = 4
    HTTP_CONNECT = 5
    HTTP_OPTIONS = 6
    HTTP_TRACE = 7
    HTTP_COPY = 8
    HTTP_LOCK = 9
    HTTP_MKCOL = 10
    HTTP_MOVE = 11
    HTTP_PROPFIND = 12
    HTTP_PROPPATCH = 13
    HTTP_SEARCH = 14
    HTTP_UNLOCK = 15
    HTTP_BIND = 16
    HTTP_REBIND = 17
    HTTP_UNBIND = 18
    HTTP_ACL = 19
    HTTP_REPORT = 20
    HTTP_MKACTIVITY = 21
    HTTP_CHECKOUT = 22
    HTTP_MERGE = 23
    HTTP_MSEARCH = 24
    HTTP_NOTIFY = 25
    HTTP_SUBSCRIBE = 26
    HTTP_UNSUBSCRIBE = 27
    HTTP_PATCH = 28
    HTTP_PURGE = 29
    HTTP_MKCALENDAR = 30
    HTTP_LINK = 31
    HTTP_UNLINK = 32

cdef class flags:
    F_CHUNKED = 1
    F_CONNECTION_KEEP_ALIVE = 2
    F_CONNECTION_CLOSE = 4
    F_CONNECTION_UPGRADE = 8
    F_TRAILING = 16
    F_UPGRADE = 32
    F_SKIPBODY = 64

cdef class http_errno:
    HPE_OK = 0
    HPE_CB_message_begin = 1
    HPE_CB_url = 2
    HPE_CB_header_field = 3
    HPE_CB_header_value = 4
    HPE_CB_headers_complete = 5
    HPE_CB_body = 6
    HPE_CB_message_complete = 7
    HPE_CB_status = 8
    HPE_CB_chunk_header = 9
    HPE_CB_chunk_complete = 10
    HPE_INVALID_EOF_STATE = 11
    HPE_HEADER_OVERFLOW = 12
    HPE_CLOSED_CONNECTION = 13
    HPE_INVALID_VERSION = 14
    HPE_INVALID_STATUS = 15
    HPE_INVALID_METHOD = 16
    HPE_INVALID_URL = 17
    HPE_INVALID_HOST = 18
    HPE_INVALID_PORT = 19
    HPE_INVALID_PATH = 20
    HPE_INVALID_QUERY_STRING = 21
    HPE_INVALID_FRAGMENT = 22
    HPE_LF_EXPECTED = 23
    HPE_INVALID_HEADER_TOKEN = 24
    HPE_INVALID_CONTENT_LENGTH = 25
    HPE_INVALID_CHUNK_SIZE = 26
    HPE_INVALID_CONSTANT = 27
    HPE_INVALID_INTERNAL_STATE = 28
    HPE_STRICT = 29
    HPE_PAUSED = 30
    HPE_UNKNOWN = 31

cdef class http_parser_type:
    HTTP_REQUEST = 0
    HTTP_RESPONSE = 1
    HTTP_BOTH = 2

cimport pyrox.http._joyent_http_parser as hp

try:
    import urllib.parse as urlparse
except ImportError:
    import urlparse
from .model import HttpHeaderCollection

cdef int on_message_begin_cb(hp.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    if parser_data.message_begin:
        parser_data.reset()
    parser_data.message_begin = True
    return 0

cdef int on_req_url_cb(hp.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef bytes url_fragment = PyBytes_FromStringAndSize(data, length)
    parser_data.url += url_fragment

    # # Set method while we're at it
    # if not parser_data.method:
    #     parser_data.method = http_method_str(parser.method)

    return 0

cdef int on_resp_status_cb(hp.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef bytes desc = PyBytes_FromStringAndSize(data, length)
    parser_data.status_desc = desc
    return 0

cdef int on_header_field_cb(hp.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef bytes header_field = PyBytes_FromStringAndSize(data, length)

    if parser_data._last_was_value:
        parser_data._last_field = b""
    parser_data._last_field += header_field
    parser_data._last_was_value = False
    return 0

cdef int on_header_value_cb(hp.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef bytes header_value = PyBytes_FromStringAndSize(data, length)

    # add to headers
    parser_data.headers[parser_data._last_field].append(header_value)
    parser_data._last_was_value = True
    return 0

cdef int on_headers_complete_cb(hp.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.headers_complete = True

    # parser_data.delegate.on_http_version(parser.http_major, parser.http_minor)
    # parser_data.delegate.on_headers_complete(
    #     keep_alive=parser_data.parser.should_keep_alive(),
    # )
    # return 0

    if parser_data.decompress:
        encoding = parser_data.headers.get('content-encoding')
        if encoding == 'gzip':
            parser_data.decompressobj = zlib.decompressobj(16 + zlib.MAX_WBITS)
            parser_data._decompress_first_try = False
            del parser_data.headers['content-encoding']
        elif encoding == 'deflate':
            parser_data.decompressobj = zlib.decompressobj()
            del parser_data.headers['content-encoding']
        else:
            parser_data.decompress = False

    return parser_data.header_only and 1 or 0

cdef int on_body_cb(hp.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef object body = PyBytes_FromStringAndSize(data, length)
    # parser_data.partial_body = True

    # parser_data.delegate.on_body(
    #     body,
    #     length,
    #     is_chunked=parser_data.parser.is_chunked,
    # )

    # decompress the body if needed
    if parser_data.decompress:
        if not parser_data._decompress_first_try:
            body = parser_data.decompressobj.decompress(body)
        else:
            try:
                body = parser_data.decompressobj.decompress(body)
            except zlib.error:
                parser_data.decompressobj = zlib.decompressobj(-zlib.MAX_WBITS)
                body = parser_data.decompressobj.decompress(body)
            parser_data._decompress_first_try = False

    parser_data.body.extend(body)
    return 0

cdef int on_message_complete_cb(hp.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    # parser_data.delegate.on_message_complete(
    #     is_chunked=parser_data.parser.is_chunked,
    #     keep_alive=parser_data.parser.should_keep_alive(),
    # )
    parser_data.message_complete = True
    return 0


# cdef int on_chunk_header_cb(hp.http_parser *parser) except -1:
#     cdef object parser_data = <object> parser.data
#     # parser_data.delegate.on_chunk_header()
#     return 0
#
#
# cdef int on_chunk_complete_cb(hp.http_parser *parser) except -1:
#     cdef object parser_data = <object> parser.data
#     # parser_data.delegate.on_chunk_complete()
#     return 0


class _ParserData(object):
    def __init__(self, parent, decompress=False, header_only=False):
        self.parent = parent
        self.decompress = decompress
        self.header_only = header_only
        self.reset()

    _headers_factory = HttpHeaderCollection
    _body_factory = bytearray

    def reset(self):
        # req
        self.url = b""

        # resp
        self.status_desc = b""

        self.headers = self._headers_factory()
        self.body = self._body_factory()

        self.chunked = False

        self.message_begin = False
        self.message_complete = False
        self.headers_complete = False
        # self.partial_body = False

        self.decompressobj = None
        self._decompress_first_try = True

        self._last_field = b""
        self._last_was_value = False

        self.parent._reset()

    def get_body(self, clear=True):
        ret = self.body
        if clear:
            self.body = self._body_factory()
        return ret

    @property
    def partial_body(self):
        return bool(self.body)


cdef class HttpParser(object):
    cdef hp.http_parser _parser
    cdef hp.http_parser_settings _settings
    cdef object _data
    cdef object _parsed_url

    def _parser_data_factory(self):
        return _ParserData(self)

    def __init__(self, kind=2, decompress=False, header_only=False):
        # set parser type
        if kind == 2:
            parser_type = hp.HTTP_BOTH
        elif kind == 1:
            parser_type = hp.HTTP_RESPONSE
        elif kind == 0:
            parser_type = hp.HTTP_REQUEST

        # init parser
        hp.http_parser_init(&self._parser, parser_type)

        self._data = self._parser_data_factory()
        self._parser.data = <void *> self._data
        self._reset()

        # set callbacks
        self._settings.on_message_begin = <http_cb> on_message_begin_cb
        self._settings.on_url = <http_data_cb> on_req_url_cb
        self._settings.on_status = <http_data_cb> on_resp_status_cb
        self._settings.on_header_field = <http_data_cb> on_header_field_cb
        self._settings.on_header_value = <http_data_cb> on_header_value_cb
        self._settings.on_headers_complete = <http_cb> on_headers_complete_cb
        self._settings.on_body = <http_data_cb> on_body_cb
        self._settings.on_message_complete = <http_cb> on_message_complete_cb
        # self._settings.on_chunk_header = <http_cb> on_chunk_header_cb
        # self._settings.on_chunk_complete = <http_cb> on_chunk_complete_cb

    def _reset(self):
        """TODO Rename this to something better."""
        self._parsed_url = None

    cpdef int execute(self, char *data, size_t length) except -1:
        cdef int nparsed

        nparsed = hp.http_parser_execute(&self._parser, &self._settings,
                                         data, length)

        if nparsed != length:
            self._raise_errno_if_needed()
            raise Exception('HttpParser did not parse all of data length but gave an OK back?')

        # Check to see if parser exited due to an upgrade
        if self._parser.upgrade == 1:
            self._delegate.on_upgrade()

        return nparsed

    cdef int _raise_errno_if_needed(self) except -1:
        cdef hp.http_errno errno = hp.HTTP_PARSER_ERRNO(&self._parser)
        cdef const char *name
        cdef const char *desc

        if errno == hp.HPE_OK:
            return 0

        name = hp.http_errno_name(errno)
        desc = hp.http_errno_description(errno)
        raise Exception(
            'HttpParser gave error {errno}/{name}: {desc}'.format(
                errno=<int> errno,
                name=name,
                desc=desc,
            ),
        )

    def pause(self):
        hp.http_parser_pause(&self._parser, 1)

    def resume(self):
        hp.http_parser_pause(&self._parser, 0)

    def body_is_final(self):
        return bool(hp.http_body_is_final(&self._parser))

    def should_keep_alive(self):
        return bool(hp.http_should_keep_alive(&self._parser))

    # @property
    # def method(self):
    #     return http_method_str(self._parser.method)

    @property
    def _flags_bits(self):
        return self._parser.flags

    @property
    def has_chunked_flag(self):
        return bool(self._flags_bits & hp.F_CHUNKED)

    @property
    def has_connection_keep_alive_flag(self):
        return bool(self._flags_bits & hp.F_CONNECTION_KEEP_ALIVE)

    @property
    def has_connection_close_flag(self):
        return bool(self._flags_bits & hp.F_CONNECTION_CLOSE)

    @property
    def has_connection_upgrade_flag(self):
        return bool(self._flags_bits & hp.F_CONNECTION_UPGRADE)

    @property
    def has_trailing_flag(self):
        return bool(self._flags_bits & hp.F_TRAILING)

    @property
    def has_upgrade_flag(self):
        return bool(self._flags_bits & hp.F_UPGRADE)

    @property
    def has_skipbody_flag(self):
        return bool(self._flags_bits & hp.F_SKIPBODY)

    def get_status_desc(self):
        """ get status reason of a response as bytes """
        return self._data.status_desc

    ''' http_parser compatible api '''

    def get_errno(self):
        """ get error state """
        return self._parser.http_errno

    def get_version(self):
        """ get HTTP version """
        return (self._parser.http_major, self._parser.http_minor)

    def get_method(self):
        """ get HTTP method as string"""
        return http_method_str(self._parser.method)

    def get_status_code(self):
        """ get status code of a response as integer """
        return self._parser.status_code

    def get_url(self):
        """ get full url of the request """
        return self._data.url

    def maybe_parse_url(self):
        raw_url = self.get_url()
        if not self._parsed_url and raw_url:
            self._parsed_url = urlparse.urlsplit(raw_url)

    ''' These were made into properties '''

    @property
    def _path(self):
        if self._parsed_url and self._parsed_url.path:
            return self._parsed_url.path
        return b""

    @property
    def _query_string(self):
        if self._parsed_url and self._parsed_url.query:
            return self._parsed_url.query
        return b""

    @property
    def _fragment(self):
        if self._parsed_url and self._parsed_url.fragment:
            return self._parsed_url.fragment
        return b""

    def get_path(self):
        """ get path of the request (url without query string and
        fragment """
        self.maybe_parse_url()
        return self._path

    def get_query_string(self):
        """ get query string of the url """
        self.maybe_parse_url()
        return self._query_string

    def get_fragment(self):
        """ get fragment of the url """
        self.maybe_parse_url()
        return self._fragment

    def get_headers(self):
        """ get request/response headers, headers are returned in a
        OrderedDict that allows you to get value using insensitive keys. """
        return self._data.headers

    def get_wsgi_environ(self):
        """ get WSGI environ based on the current request """
        # TODO Conversion to str no longer happens so this is broken
        self.maybe_parse_url()

        environ = dict()
        script_name = os.environ.get("SCRIPT_NAME", "")
        for key, val in self._data.headers.items():
            ku = key.upper()
            if ku == "CONTENT-TYPE":
                environ['CONTENT_TYPE'] = val
            elif ku == "CONTENT-LENGTH":
                environ['CONTENT_LENGTH'] = val
            elif ku == "SCRIPT_NAME":
                environ['SCRIPT_NAME'] = val
            else:
                environ['HTTP_%s' % ku.replace('-', '_')] = val

        if script_name:
            path_info = self._path.split(script_name, 1)[1]
        else:
            path_info = self._path

        environ.update({
            'REQUEST_METHOD': self.get_method(),
            'SERVER_PROTOCOL': "HTTP/%s" % ".".join(map(str,
                                                        self.get_version())),
            'PATH_INFO': path_info,
            'SCRIPT_NAME': script_name,
            'QUERY_STRING': self._query_string,
            'RAW_URI': self._data.url
        })

        return environ

    def recv_body(self):
        """ return last chunk of the parsed body"""
        body = self._data.get_body()
        return body

    def recv_body_into(self, barray):
        """ Receive the last chunk of the parsed body and store the data
        in a buffer rather than creating a new string. """
        l = len(barray)
        body = self._data.get_body(clear=False)
        m = min(len(body), l)
        data, self._data.body = body[:m], body[m:]
        barray[0:m] = data
        return m

    def is_upgrade(self):
        """ Do we get upgrade header in the request. Useful for
        websockets """
        return self._parser_upgrade

    def is_headers_complete(self):
        """ return True if all headers have been parsed. """
        return self._data.headers_complete

    def is_partial_body(self):
        """ return True if a chunk of body have been parsed """
        return self._data.partial_body

    def is_message_begin(self):
        """ return True if the parsing start """
        return self._data.message_begin

    def is_message_complete(self):
        """ return True if the parsing is done (we get EOF) """
        return self._data.message_complete

    def is_chunked(self):
        """ return True if Transfer-Encoding header value is chunked"""
        # return self.has_chunked_flag
        te = self._data.headers.get('transfer-encoding', '').lower()
        return te == 'chunked'
