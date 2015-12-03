import collections
import six
import sys

_EMPTY_HEADER_VALUES = ()


class lowerstr(str):
    """Lowercase optimized str."""

    def __new__(cls, val='', encoding=sys.getdefaultencoding(), errors='strict'):
        if six.PY3 and isinstance(val, (bytes, bytearray, memoryview)):
            val = str(val, encoding, errors)
        elif isinstance(val, str):
            pass
        else:
            val = str(val)
        val = val.lower()
        return str.__new__(cls, val)

    def lower(self):
        return self


def _to_bytes(value, encoding='utf8'):
    if isinstance(value, six.binary_type):
        return value
    elif isinstance(value, six.text_type):
        return value.encode(encoding)
    else:
        raise ValueError("Cannot coerce type:%s=%s to bytes", type(value), value)


class HttpHeaderCollection(collections.MutableMapping):
    def __init__(self, *args, **kwargs):
        super(HttpHeaderCollection, self).__init__()
        self._names = dict()
        self._store = dict()
        self.update(dict(*args, **kwargs))

    def __repr__(self):
        return '<%s %s>' % (self.__class__.__name__, list(self))

    def as_dict(self):
        """
        Returns a dict of headers in collection, with keys being the original cased names the headers were added with.
        """
        return {self._names[k]: self._store[k] for k in self._store}

    def _header_factory(self, name, value):
        if isinstance(value, six.string_types):
            value = [value]
        elif value is None:
            value = []
        elif isinstance(value, collections.Sequence):
            value = list(value)
        else:
            value = [str(value)]

        if not isinstance(value, list):
            raise ValueError('Cannot set header %s; value must be a sequence: %s' % (name, value))
        return value

    def __key_transform__(self, key):
        return lowerstr(key)

    def __getitem__(self, key, auto_create=True):
        tkey = self.__key_transform__(key)

        if tkey not in self._store and auto_create:
            self[key] = None

        return self._store[tkey]

    def __setitem__(self, key, value):
        tkey = self.__key_transform__(key)

        if not isinstance(value, list):
            value = self._header_factory(key, value)

        self._names[tkey] = key
        self._store[tkey] = value

    def __delitem__(self, key):
        key = self.__key_transform__(key)
        del self._store[key]
        del self._names[key]

    def __iter__(self):
        return iter(self._store)

    def __contains__(self, key):
        tkey = self.__key_transform__(key)
        return tkey in self._store

    def __len__(self):
        return len(self._store)

    def original_names(self):
        """
        Returns a list of the original (case sensitive) names that headers were added with.
        """
        return self._names.values()

    def get(self, key, default=None, remove=False, auto_create=True):
        """
        Returns the header values at key (case insensitive match).
        If header does not exist, default is returned.
        If remove is True, also remove the values (ala pop).
        """
        if remove:
            return self.pop(key, default)
        tkey = self.__key_transform__(key)
        if tkey not in self:
            return default

        return self.__getitem__(key, auto_create=auto_create)

    __marker = object()

    def pop(self, key, default=__marker):
        """
        Returns the header values at key (case insensitive match) then removes the header.
        If header does not exist, KeyError is raised, or if default is specified, default is returned.
        """
        key = self.__key_transform__(key)
        if default is not self.__marker and key not in self:
            return default
        return super(HttpHeaderCollection, self).pop(key)

    def first(self, key, default=None, remove=False):
        """
        Returns the first header value in the list under key (case-insensitive matched).
        If the header does not exist, default is returned.
        """
        values = self.get(key, default, remove=remove)
        if values and values is not default:
            return values[0]
        return default

    def get_or_set(self, key, default=None):
        """
        Returns the header that matches the name via case-insensitive matching.
        If the header does not exist, a new header is created, attached to the
        message and returned. If the header already exists, then it is
        returned.
        """
        if key not in self:
            self[key] = default
        return self[key]

    def replace(self, name, value=None):
        """
        Returns a new header with a field set to name. If the header exists
        then the header is removed from the request first.
        """
        self.remove(name)
        self[name] = value
        return self[name]

    def remove(self, name):
        """
        Removes the header that matches the name via case-insensitive matching.
        If the header exists, it is removed and a result of True is returned.
        If the header does not exist then a result of False is returned.
        """
        if name in self:
            del self[name]
            return True
        return False

    def _header_to_bytes(self, name, values, data):
        data.extend(_to_bytes(name))
        data.extend(b': ')

        if values:
            data.extend(b', '.join([_to_bytes(v) for v in values]))

        data.extend(b'\r\n')

    def to_bytes(self, data):
        for name in self.original_names():
            values = self.get(name, default=[], auto_create=False)
            self._header_to_bytes(name, values, data)

        # TODO This probably shouldn't be done on CONNECT requests.
        # needs_content_length = 'content-length' not in self
        needs_content_length = False
        has_transfer_encoding = 'transfer-encoding' in self

        if needs_content_length and not has_transfer_encoding:
            self._header_to_bytes(b'Content-Length', b'0', data)

        data.extend(b'\r\n')


class HttpMessage(object):
    """
    Parent class for requests and responses. Many of the elements in the
    messages share common structures.

    Attributes:
        headers     A dictionary of the headers currently stored in this
                    HTTP message.

        version     A bytearray or string value representing the major-minor
                    version of the HttpMessage.

        local_data  The local_data variable is a dictionary that may be
                    used as a holding place for data that other filters
                    may then access and utilize. Setting entries in this
                    dictionary does not modify the HTTP model in anyway.

        peek_size   Int value of how much data (in bytes) to peek up to before sending data back to downstream.
    """
    peek_size = 0

    def __init__(self, version=b'1.1'):
        self.version = version
        self.local_data = dict()

        self.headers = HttpHeaderCollection()
        self.set_default_headers()

    def set_default_headers(self):
        """
        Allows messages to set default headers that must be added to the
        message before its construction is complete.
        """
        # self.headers.setdefault('Content-Length', [0])
        pass

    def header(self, name):
        """
        Returns the header that matches the name via case-insensitive matching.
        If the header does not exist, a new header is created, attached to the
        message and returned. If the header already exists, then it is
        returned.
        """
        return self.headers.get_or_set(name)

    def replace_header(self, name):
        """
        Returns a new header with a field set to name. If the header exists
        then the header is removed from the request first.
        """
        return self.headers.replace(name)

    def get_header(self, name, default=None):
        """
        Returns the header that matches the name via case-insensitive matching.
        Unlike the header function, if the header does not exist then a None
        result is returned.
        """
        return self.headers.get(name, default=default)

    def remove_header(self, name):
        """
        Removes the header that matches the name via case-insensitive matching.
        If the header exists, it is removed and a result of True is returned.
        If the header does not exist then a result of False is returned.
        """
        return self.headers.remove(name)

    def switch_to_chunked(self):
        """
        Switches headers to signify we're using chunked encoding.
        """
        if self.version == b'1.0':
            raise Exception("Cannot switch to chunked mode on HTTP/1.0 requests.")

        # If there's a content length, negotiate the transfer encoding
        if 'content-length' in self.headers:
            self.headers.pop('content-length')

        # Set to chunked to make the transfer easier
        self.headers['transfer-encoding'] = 'chunked'

    def to_bytes(self):
        raise NotImplementedError


class HttpRequest(HttpMessage):
    """
    HttpRequest defines the HTTP request attributes that will be available
    to a HttpFilter.

    Attributes:
        method          A bytearray or string value representing the request's
                        method verb.

        url             A bytearray or string value representing the requests'
                        uri path including the query and fragment string.

        client_address  Tuple of client host, port
    """
    method = None
    url = None
    socket_client_address = None
    _client_address = None

    @property
    def client_address(self):
        if self._client_address:
            return self._client_address
        return self.socket_client_address

    @client_address.setter
    def client_address_setter(self, value):
        self._client_address = value

    def to_bytes(self):
        data = bytearray()
        data.extend(_to_bytes(self.method))
        data.extend(b' ')
        data.extend(_to_bytes(self.url))
        data.extend(b' HTTP/')
        data.extend(_to_bytes(self.version))
        data.extend(b'\r\n')
        self.headers.to_bytes(data)
        return bytes(data)


class HttpResponse(HttpMessage):
    """
    HttpResponse defines the HTTP response attributes that will be available
    to a HttpFilter.

    Attributes:
        status      A string representing the response's status code and
                    potentially its human readable component delimited by
                    a single space.
    """
    status = None

    def to_bytes(self):
        data = bytearray()
        data.extend(b'HTTP/')
        data.extend(self.version)
        data.extend(b' ')
        data.extend(_to_bytes(self.status))
        data.extend(b'\r\n')
        self.headers.to_bytes(data)
        return bytes(data)
