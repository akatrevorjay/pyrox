from libc.stdlib cimport malloc, free
from libc.string cimport strlen

from cpython cimport bool, PyBytes_FromStringAndSize, PyBytes_FromString

from http_parser cimport HTTP_REQUEST, HTTP_RESPONSE, http_parser_type, flags, http_parser_url_fields, http_parser_url, http_parser_version, http_parser, http_parser_settings, http_parser_init, http_parser_execute, http_should_keep_alive, http_parser_pause, http_body_is_final

def RequestParser(parser_delegate):
    return HttpEventParser(parser_delegate, HTTP_REQUEST)

def ResponseParser(parser_delegate):
    return HttpEventParser(parser_delegate, HTTP_RESPONSE)

cdef int on_url(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.data
    cdef object url_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_url(url_str)
    return 0


class ParserDelegate(object):
    def on_url(self, url):
        print(url)


cdef class ParserData(object):
    cdef public object delegate

    def __cinit__(self, object delegate):
        self.delegate = delegate

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

cdef class HttpEventParser(object):
    cdef http_parser *_parser
    cdef http_parser_settings _settings
    cdef object app_data

    def __cinit__(self, object delegate, parser_type):
        # initialize parser
        self._parser = <http_parser *> malloc(sizeof(http_parser))
        http_parser_init(self._parser, parser_type)

        self.app_data = ParserData(delegate)
        self._parser.data = <void *> self.app_data

        # set callbacks
        self._settings.on_url = <http_data_cb> on_url

    def destroy(self):
        if self._parser != NULL:
            free(self._parser)
            self._parser = NULL

    def __dealloc__(self):
        self.destroy()

    def execute(self, data):
        data = to_bytes(data)
        return self._execute(data, len(data))

    cdef int _execute(self, char *data, size_t length):
        cdef int retval

        if self._parser == NULL:
            raise Exception('Parser destroyed or not initialized!')

        retval = http_parser_execute(self._parser, &self._settings, data, length)
        if retval:
            raise Exception('Failed with errno: {}'.format(retval))

        return 0
