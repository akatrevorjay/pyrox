#cython: c_string_encoding=ascii  # for cython>=0.19
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
cimport http_parser
import collections
import six
from http_parser cimport http_cb
from http_parser cimport http_data_cb
from http_parser cimport flags as _flags
from http_parser cimport http_errno as _http_errno
from http_parser cimport http_method as _http_method
from http_parser cimport http_parser_type as _http_parser_type
from http_parser cimport http_parser_url_fields as _http_parser_url_fields
from http_parser cimport HTTP_PARSER_ERRNO as _HTTP_PARSER_ERRNO_http_parser
from http_parser cimport http_body_is_final as _http_body_is_final_http_parser
from http_parser cimport http_errno_description as _http_errno_description_http_parser
from http_parser cimport http_errno_name as _http_errno_name_http_parser
from http_parser cimport http_method_str as _http_method_str_http_parser
from http_parser cimport http_parser_execute as _http_parser_execute_http_parser
from http_parser cimport http_parser_init as _http_parser_init_http_parser
from http_parser cimport http_parser_parse_url as _http_parser_parse_url_http_parser
from http_parser cimport http_parser_pause as _http_parser_pause_http_parser
from http_parser cimport http_parser_url_init as _http_parser_url_init_http_parser
from http_parser cimport http_parser_version as _http_parser_version_http_parser
from http_parser cimport http_should_keep_alive as _http_should_keep_alive_http_parser
cdef extern from "autowrap_tools.hpp":
    char * _cast_const_away(char *)

def http_errno_description(int err ):
    assert err in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31], 'arg err wrong type'

    cdef char  * _r = _cast_const_away(_http_errno_description_http_parser((<_http_errno>err)))
    py_result = <char *>(_r)
    return py_result

def http_errno_name(int err ):
    assert err in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31], 'arg err wrong type'

    cdef char  * _r = _cast_const_away(_http_errno_name_http_parser((<_http_errno>err)))
    py_result = <char *>(_r)
    return py_result

def http_method_str(int m ):
    assert m in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32], 'arg m wrong type'

    cdef char  * _r = _cast_const_away(_http_method_str_http_parser((<_http_method>m)))
    py_result = <char *>(_r)
    return py_result

def http_parser_version():
    cdef unsigned long int _r = _http_parser_version_http_parser()
    py_result = <unsigned long int>_r
    return py_result 

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

cdef class flags:
    F_CHUNKED = 1
    F_CONNECTION_KEEP_ALIVE = 2
    F_CONNECTION_CLOSE = 4
    F_CONNECTION_UPGRADE = 8
    F_TRAILING = 16
    F_UPGRADE = 32
    F_SKIPBODY = 64 

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

cdef class http_parser_url_fields:
    UF_SCHEMA = 0
    UF_HOST = 1
    UF_PORT = 2
    UF_PATH = 3
    UF_QUERY = 4
    UF_FRAGMENT = 5
    UF_USERINFO = 6
    UF_MAX = 7 

cdef class http_parser_type:
    HTTP_REQUEST = 0
    HTTP_RESPONSE = 1
    HTTP_BOTH = 2 
try:
    import urllib.parse as urlparse
except ImportError:
    import urlparse

def to_bytes(data):
    if isinstance(data, bytes):
        pass
    elif isinstance(data, unicode):
        data = data.encode('utf8')
    elif isinstance(data, (list, bytearray)):
        data = bytes(data)
    else:
        raise Exception('Can not coerce type: {} into bytes.'.format(type(data)))
    return data

cdef int on_message_begin(http_parser.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.delegate.on_message_begin()
    return 0

cdef int on_req_url(http_parser.http_parser *parser, char *data, size_t length) except -1:
    """ Request only """
    cdef object parser_data = <object> parser.data
    cdef http_parser.http_method method_int = <http_parser.http_method> parser.method
    cdef const char* method = http_parser.http_method_str(method_int)
    cdef object url = PyBytes_FromStringAndSize(data, length)
    parser_data.delegate.on_req_method(method)
    parser_data.delegate.on_req_url(url)
    return 0

cdef int on_resp_status(http_parser.http_parser *parser, char *data, size_t length) except -1:
    """ Response only """
    cdef object parser_data = <object> parser.data
    cdef object status = PyBytes_FromStringAndSize(data, length)
    parser_data.delegate.on_resp_status(parser.status_code, status)
    return 0

cdef int on_header_field(http_parser.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef object header_field = PyBytes_FromStringAndSize(data, length)
    parser_data.delegate.on_header_field(header_field)
    return 0

cdef int on_header_value(http_parser.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef object header_value = PyBytes_FromStringAndSize(data, length)
    parser_data.delegate.on_header_value(header_value)
    return 0

cdef int on_headers_complete(http_parser.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.delegate.on_http_version(parser.http_major, parser.http_minor)
    parser_data.delegate.on_headers_complete(
        keep_alive=parser_data.parent.should_keep_alive(),
        #flags=parser_data._flags_bits,
    )
    return 0

cdef int on_body(http_parser.http_parser *parser, char *data, size_t length) except -1:
    cdef object parser_data = <object> parser.data
    cdef object body = PyBytes_FromStringAndSize(data, length)
    parser_data.delegate.on_body(
        body,
        length,
        is_chunked=parser_data.has_chunked_flag,
    )
    return 0

cdef int on_message_complete(http_parser.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.delegate.on_message_complete(
        is_chunked=parser_data.has_chunked_flag,
        keep_alive=parser_data.parent.should_keep_alive(),
        #flags=parser_data._flags_bits,
    )
    return 0

cdef int on_chunk_header(http_parser.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.delegate.on_chunk_header()
    return 0

cdef int on_chunk_complete(http_parser.http_parser *parser) except -1:
    cdef object parser_data = <object> parser.data
    parser_data.delegate.on_chunk_complete()
    return 0


class ParserDelegate(object):
    def on_message_begin(self):
        pass

    def on_req_method(self, method):
        pass

    def on_req_url(self, url):
        pass

    def on_resp_status(self, code, desc):
        pass

    def on_header_field(self, field):
        pass

    def on_header_value(self, value):
        pass

    def on_http_version(self, major, minor):
        pass

    def on_headers_complete(self, keep_alive):
        pass

    def on_body(self, data, length, is_chunked):
        pass

    def on_message_complete(self, is_chunked, keep_alive):
        pass

    def on_chunk_header(self):
        pass

    def on_chunk_complete(self):
        pass

    def on_upgrade(self):
        pass


cdef class _ParserData(object):
    cdef public object parent
    cdef public object delegate

    def __cinit__(self, object parent, object delegate):
        self.parent = parent
        self.delegate = delegate

    def should_keep_alive(self):
        return self.parent.should_keep_alive()

    def body_is_final(self):
        return self.parent.body_is_final()

    @property
    def _flags_bits(self):
        return self.parent._flags_bits

    @property
    def has_chunked_flag(self):
        return bool(self._flags_bits & http_parser.F_CHUNKED)

    @property
    def has_connection_keep_alive_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_KEEP_ALIVE)

    @property
    def has_connection_close_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_CLOSE)

    @property
    def has_connection_upgrade_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_UPGRADE)

    @property
    def has_trailing_flag(self):
        return bool(self._flags_bits & http_parser.F_TRAILING)

    @property
    def has_upgrade_flag(self):
        return bool(self._flags_bits & http_parser.F_UPGRADE)

    @property
    def has_skipbody_flag(self):
        return bool(self._flags_bits & http_parser.F_SKIPBODY)


cdef class Parser(object):
    cdef http_parser.http_parser *_parser
    cdef http_parser.http_parser_settings _settings
    cdef public object delegate
    cdef public object data

    def __cinit__(self, http_parser.http_parser_type parser_type, object delegate):
        # init parser
        self._parser = <http_parser.http_parser *> malloc(sizeof(http_parser.http_parser))
        http_parser.http_parser_init(self._parser, parser_type)

        self.delegate = delegate
        self.data = _ParserData(self, delegate)
        self._parser.data = <void *> self.data

        # set callbacks
        self._settings.on_message_begin = <http_cb> on_message_begin
        self._settings.on_url = <http_data_cb> on_req_url
        self._settings.on_status = <http_data_cb> on_resp_status
        self._settings.on_header_field = <http_data_cb> on_header_field
        self._settings.on_header_value = <http_data_cb> on_header_value
        self._settings.on_headers_complete = <http_cb> on_headers_complete
        self._settings.on_body = <http_data_cb> on_body
        self._settings.on_message_complete = <http_cb> on_message_complete
        self._settings.on_chunk_header = <http_cb> on_chunk_header
        self._settings.on_chunk_complete = <http_cb> on_chunk_complete

    def destroy(self):
        if self._parser != NULL:
            free(self._parser)
            self._parser = NULL

    def __dealloc__(self):
        self.destroy()

    def execute(self, data):
        data = to_bytes(data)
        return self._execute(data, len(data))

    cdef int _execute(self, char *data, size_t length) except -1:
        cdef int nparsed

        self._assert_parser()

        nparsed = http_parser.http_parser_execute(self._parser, &self._settings, data, length)

        if nparsed != length:
            self._raise_errno_if_needed()
            raise Exception('Parser did not parse all of data length but gave an OK back?')

        # Check to see if parser exited due to an upgrade
        if self._parser.upgrade == 1:
            self.delegate.on_upgrade()

        return nparsed

    cdef int _raise_errno_if_needed(self) except -1:
        cdef http_parser.http_errno errno = http_parser.HTTP_PARSER_ERRNO(self._parser)
        cdef const char * name
        cdef const char * desc

        if errno == http_parser.HPE_OK:
            return 0

        name = http_parser.http_errno_name(errno)
        desc = http_parser.http_errno_description(errno)
        raise Exception('Parser gave error {errno}/{name}: {desc}'.format(errno=<int>errno,
                                                                            name=name,
                                                                            desc=desc))

    cdef int _assert_parser(self) except -1:
        if self._parser == NULL:
            raise Exception('Parser destroyed or not initialized!')

    def pause(self):
        self._assert_parser()
        http_parser.http_parser_pause(self._parser, 1)

    def resume(self):
        self._assert_parser()
        http_parser.http_parser_pause(self._parser, 0)

    def body_is_final(self):
        self._assert_parser()
        return bool(http_parser.http_body_is_final(self._parser))

    def should_keep_alive(self):
        self._assert_parser()
        return bool(http_parser.http_should_keep_alive(self._parser))

    @property
    def _flags_bits(self):
        self._assert_parser()
        return self._parser.flags

    @property
    def has_chunked_flag(self):
        return bool(self._flags_bits & http_parser.F_CHUNKED)

    @property
    def has_connection_keep_alive_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_KEEP_ALIVE)

    @property
    def has_connection_close_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_CLOSE)

    @property
    def has_connection_upgrade_flag(self):
        return bool(self._flags_bits & http_parser.F_CONNECTION_UPGRADE)

    @property
    def has_trailing_flag(self):
        return bool(self._flags_bits & http_parser.F_TRAILING)

    @property
    def has_upgrade_flag(self):
        return bool(self._flags_bits & http_parser.F_UPGRADE)

    @property
    def has_skipbody_flag(self):
        return bool(self._flags_bits & http_parser.F_SKIPBODY)


def BothParser(parser_delegate):
    return Parser(http_parser.HTTP_BOTH, parser_delegate)


def RequestParser(parser_delegate):
    return Parser(http_parser.HTTP_REQUEST, parser_delegate)


def ResponseParser(parser_delegate):
    return Parser(http_parser.HTTP_RESPONSE, parser_delegate)


class ParseResult(collections.namedtuple('ParseResult',
                                         ['scheme', 'hostname', 'port', 'raw_path', 'query', 'fragment', 'userinfo'])):
    __slots__ = ()

    @property
    def netloc(self):
        ret = []
        if self.userinfo:
            ret.append(self.userinfo)
            ret.append(b'@')
        if self.hostname:
            ret.append(self.hostname)
        if self.port:
            ret.append(b':')
            if six.PY3:
                ret.append(bytes(str(self.port), 'ascii'))
            else:
                ret.append(str(self.port))
        return b''.join(ret)

    @property
    def path(self):
        return self.raw_path.split(b';', 1)[0]

    @property
    def params(self):
        if b';' in self.raw_path:
            return self.raw_path.split(b';', 1)
        else:
            return b''

    @property
    def username(self):
        if not self.userinfo:
            return
        return self.userinfo.split(b':', 1)[0]

    @property
    def password(self):
        if not self.userinfo:
            return
        return self.userinfo.split(b':', 1)[1]

    def as_strings(self):
        if six.PY3:
            args = [i == 2 and str(x) or x.decode() for i, x in enumerate(self)]
        else:
            args = self
        return self.__class__(*args)

    def _as_urlparse_result_tuple(self):
        ret = [self.scheme, self.netloc, self.path, self.params, self.query, self.fragment]
        if six.PY3:
            ret = [x.decode() for x in ret]
        return ret

    def as_urlparse_result(self):
        return urlparse.ParseResult(*self._as_urlparse_result_tuple())

    def geturl(self):
        return urlparse.urlunparse(self._as_urlparse_result_tuple())


cdef class HttpUrlParser(object):
    cdef http_parser.http_parser_url *_parser
    cdef object data

    def __cinit__(self):
        # init parser
        self._parser = <http_parser.http_parser_url *> malloc(sizeof(http_parser.http_parser_url))
        http_parser.http_parser_url_init(self._parser)

    def destroy(self):
        if self._parser != NULL:
            free(self._parser)
            self._parser = NULL

    def __dealloc__(self):
        self.destroy()

    def parse(self, url, is_connect):
        url = to_bytes(url)
        ret = self._parse(url, len(url), is_connect)
        return ParseResult(*ret)

    cdef object _parse(self, char *url, size_t length, bool is_connect):
        cdef int rv
        cdef object ret

        if self._parser == NULL:
            raise Exception('Parser destroyed or not initialized!')

        rv = http_parser.http_parser_parse_url(url, length, is_connect, self._parser)
        if rv != 0:
            raise Exception('URL Parser gave error: {rv}'.format(rv=rv))

        ret = []
        for i in range(http_parser.UF_MAX):
            if i == http_parser.UF_PORT:
                # This is so it's an integer as expected
                if self._parser.port:
                    ret.append(self._parser.port)
                else:
                    # Match urlparse
                    ret.append(None)
            elif self._parser.field_set & (1 << i) == 0:
                ret.append('')
            else:
                f_off = self._parser.field_data[i].off
                f_len = self._parser.field_data[i].len
                part = url[f_off:f_off + f_len]
                ret.append(part)

        return ret 
