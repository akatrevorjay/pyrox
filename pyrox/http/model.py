from .model_util import request_to_bytes, response_to_bytes
import collections
import types

_EMPTY_HEADER_VALUES = ()


class HttpHeader(collections.MutableSequence):
    """
    Defines the fields for a HTTP header

    Attributes:
        name        A bytearray or string value representing the field-name of
                    the header.
    """

    def __init__(self, name, values_ref=None):
        self.name = name
        if values_ref is None:
            values_ref = []
        if not isinstance(values_ref, collections.Sequence):
            raise ValueError('Cannot set key %s; value is not a sequence: %s' % (key, value))
        self.values = values_ref

    def __repr__(self):
        return "<%s '%s' %s>" % (self.__class__.__name__, self.name, self.values)

    def __getitem__(self, item):
        return self.values[item]

    def insert(self, index, value):
        self.values[index] = value

    __setitem__ = insert

    def __delitem__(self, key):
        del self.values[key]

    def __len__(self):
        return len(self.values)

    def clear(self):
        del self.values[:]

    def get(self, idx, default=None):
        if len(self) > idx:
            return self[idx]
        return default

    def first(self, default=None):
        return self.get(0, default=default)


class HttpHeaderCollection(collections.MutableMapping):
    def __init__(self, *args, **kwargs):
        self._store = dict()
        self.update(dict(*args, **kwargs))

    def __repr__(self):
        return '<%s %s>' % (self.__class__.__name__, self._store.values())

    def _header_factory(self, name, values_ref=None):
        return HttpHeader(name, values_ref)

    def __key_transform__(self, key):
        return key.lower()

    def __getitem__(self, key):
        tkey = self.__key_transform__(key)
        return self._store[tkey]

    def __setitem__(self, key, value):
        tkey = self.__key_transform__(key)

        # Coerce value to HttpHeader
        if not isinstance(value, HttpHeader):
            value = self._header_factory(key, value)

        self._store[tkey] = value

    def __delitem__(self, key):
        key = self.__key_transform__(key)
        del self._store[key]

    def __iter__(self):
        return iter(self._store)

    def __len__(self):
        return len(self._store)

    def get_header(self, key, default=None):
        if key not in self:
            return self._header_factory(key, default)
        return self[key]

    def pop_header(self, key, default=None):
        if key not in self:
            return self._header_factory(key, default)
        return self.pop(key)

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

    def get_header(self, name, default=None, remove=False):
        """
        Returns the header that matches the name via case-insensitive matching.
        Unlike the header function, if the header does not exist then a None
        result is returned.
        """
        if remove:
            return self.headers.pop_header(name, default=default)
        else:
            return self.headers.get(name, default=default)

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
