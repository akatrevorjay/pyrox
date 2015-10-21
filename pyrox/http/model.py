from .model_util import request_to_bytes, response_to_bytes
import collections
import types

_EMPTY_HEADER_VALUES = ()


class HttpHeaderCollection(collections.MutableMapping):
    def __init__(self, *args, **kwargs):
        super(HttpHeaderCollection, self).__init__()
        self._names = dict()
        self._store = dict()
        self.update(dict(*args, **kwargs))

    def __repr__(self):
        return '<%s %s>' % (self.__class__.__name__, list(self))

    def as_dict(self):
        # This maps the key names to their non-transformed versions, as well as removes empty values
        return {self._names[k]: self._store[k] for k in self._store
                if self._store[k]}

    def _header_factory(self, name, value):
        if isinstance(value, (int, bool)):
            value = [str(value)]
        elif isinstance(value, types.StringTypes):
            value = [value]
        elif value is None:
            value = []
        elif isinstance(value, collections.Sequence):
            value = list(value)

        if not isinstance(value, list):
            raise ValueError('Cannot set header %s; value must be a sequence: %s' % (name, value))
        return value

    def __key_transform__(self, key):
        return key.lower()

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
        return self._names.values()

    def get(self, key, default=None, remove=False):
        if remove:
            return self.pop(key, default)
        key = self.__key_transform__(key)
        if key not in self:
            return default
        return self[key]

    __marker = object()

    def pop(self, key, default=__marker):
        key = self.__key_transform__(key)
        if default is not self.__marker and key not in self:
            return default
        return super(HttpHeaderCollection, self).pop(key)

    def first(self, key, default=None, remove=False):
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

    def __init__(self, version='1.1'):
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

    def pop_header(self, name, default=None):
        return self.headers.pop(name, default)

    def remove_header(self, name):
        """
        Removes the header that matches the name via case-insensitive matching.
        If the header exists, it is removed and a result of True is returned.
        If the header does not exist then a result of False is returned.
        """
        return self.headers.remove(name)

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
    client_address = None

    def to_bytes(self):
        return request_to_bytes(self)


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
        return response_to_bytes(self)
