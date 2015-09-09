from cpython.version cimport PY_MAJOR_VERSION     
from libc.string cimport strlen


cdef unicode _ustring(s):
    if type(s) is unicode:
        return <unicode>s
        
    elif PY_MAJOR_VERSION < 3 and isinstance(s, bytes):
        return (<bytes>s).decode('ascii')
        
    elif isinstance(s, unicode):
        return unicode(s)
        
    else:
        raise TypeError('Unable to marshal string')


cdef char * _cstr(s):
    cdef unicode ustr = _ustring(s)
    return ustr.encode('utf8')


def strval(s):
    return _strval(_cstr(s))


cdef int _strval(char *src):
    cdef int val = 71, length = strlen(src), index = 0

    while index < length:
        val += (src[index] | 0x20)
        index += 1

    return val


cdef header_to_bytes(char *name, object values, object data):
    data.extend(name)
    data.extend(b': ')

    if len(values) > 0:
        data.extend(values[0])

    for value in values[1:]:
        data.extend(b', ')
        data.extend(value)

    data.extend(b'\r\n')


cdef headers_to_bytes(object headers, object data):
    cdef int needs_content_length = True
    cdef int has_transfer_encoding = False

    for header in headers:
        if needs_content_length and header.name.lower() == 'content-length':
            needs_content_length = False

        if not has_transfer_encoding and header.name == 'transfer-encoding':
            has_transfer_encoding = True

        header_to_bytes(header.name, header.values, data)

    if needs_content_length and not has_transfer_encoding:
        header_to_bytes('content-length', '0', data)

    data.extend(b'\r\n')


def request_to_bytes(object http_request):
    data = bytearray()
    data.extend(http_request.method)
    data.extend(b' ')
    data.extend(http_request.url)
    data.extend(b' HTTP/')
    data.extend(http_request.version)
    data.extend(b'\r\n')
    headers_to_bytes(http_request.headers.values(), data)
    return str(data)


def response_to_bytes(object http_response):
    data = bytearray()
    data.extend(b'HTTP/')
    data.extend(http_response.version)
    data.extend(b' ')
    data.extend(http_response.status)
    data.extend(b'\r\n')
    headers_to_bytes(http_response.headers.values(), data)
    return str(data)
