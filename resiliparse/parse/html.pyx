# Copyright 2021 Janek Bevendorff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# distutils: language = c++

import typing as t

from resiliparse_inc.lexbor cimport *

from resiliparse.parse.encoding cimport bytes_to_str, map_encoding_to_html5


cdef inline Node _node_from_dom(lxb_dom_node_t* dom_node):
    if dom_node == NULL:
        return None
    cdef Node node = Node.__new__(Node)
    node.node = dom_node
    return node


cdef inline Attribute _attr_from_dom(lxb_dom_attr_t* attr_node):
    if attr_node == NULL:
        return None
    cdef Attribute node = Attribute.__new__(Attribute)
    node.attr = attr_node
    return node


cdef class Attribute:
    """
    A HTML DOM attribute.

    This element is only valid as long as the owning :class:``HTMLTree` and :class:`Node` are
    alive and the DOM tree hasn't been modified. Do not access ``Node`` instances after any
    sort of DOM tree manipulation.
    """

    def __cinit__(self):
        self.attr = NULL

    @property
    def name(self):
        """
        Attribute name.

        :rtype: str | None
        """
        if self.attr == NULL:
            return None

        cdef size_t name_len = 0
        cdef const lxb_char_t* name = lxb_dom_attr_local_name(self.attr, &name_len)
        if name == NULL:
            return None
        return bytes_to_str(name[:name_len])

    @property
    def value(self):
        """
        Attribute value.

        :rtype: str | None
        """
        if self.attr == NULL:
            return None
        cdef size_t val_len = 0
        cdef const lxb_char_t* val = lxb_dom_attr_value(self.attr, &val_len)
        return bytes_to_str(val[:val_len])

    def __repr__(self):
        return f'{self.name}="{self.value}"'

    def __str__(self):
        return self.value


cdef class Node:
    """
    A HTML DOM node.

    A DOM node and its children is iterable and will traverse the DOM tree in pre-order.

    This element is only valid as long as the owning :class:``HTMLTree` is alive
    and the DOM tree hasn't been modified. Do not access ``Node`` instances
    after any sort of DOM tree manipulation.
    """

    def __cinit__(self):
        self.node = NULL

    def __iter__(self):
        """
        Iterate DOM tree from current node in pre-order.

        :rtype: t.Iterable[Node]
        """
        if self.node == NULL:
            return

        yield self
        cdef lxb_dom_node_t* node = self.node
        while True:
            if node.first_child != NULL:
                node = node.first_child
            else:
                while node != self.node and node.next == NULL:
                    node = node.parent
                if node == self.node:
                    return
                node = node.next

            yield _node_from_dom(node)

    @property
    def type(self):
        """
        DOM node type.

        :rtype: NodeType | None
        """
        if self.node == NULL:
            return None
        return <NodeType>self.node.type

    @property
    def tag(self):
        """
        DOM node tag name.

        :return: str | None
        """
        if self.node == NULL or self.node.type != LXB_DOM_NODE_TYPE_ELEMENT:
            return None
        cdef size_t name_len = 0
        cdef unsigned char* name = <unsigned char*>lxb_dom_element_qualified_name(
            <lxb_dom_element_t*>self.node, &name_len)
        if name == NULL:
            return None
        return bytes_to_str(name[:name_len])

    @property
    def first_child(self):
        """
        First child element of this DOM node.

        :rtype: Node | None
        """
        if self.node == NULL:
            return None
        return _node_from_dom(self.node.first_child)

    @property
    def last_child(self):
        """
        Last child element of this DOM node.

        :rtype: Node | None
        """
        if self.node == NULL:
            return None
        return _node_from_dom(self.node.last_child)

    @property
    def parent(self):
        """
        Parent of this node.

        :rtype: Node | None
        """
        if self.node == NULL:
            return None
        return _node_from_dom(self.node.parent)

    @property
    def next(self):
        """
        Next sibling node.

        :rtype: Node | None
        """
        if self.node == NULL:
            return None
        return _node_from_dom(self.node.next)

    @property
    def prev(self):
        """
        Previous sibling node.

        :rtype: Node | None
        """
        if self.node == NULL:
            return None
        return _node_from_dom(self.node.prev)

    @property
    def text(self):
        """
        Text contents of this DOM node and its children.

        :rtype: str | None
        """
        if self.node == NULL:
            return None
        cdef size_t text_len = 0
        cdef lxb_char_t* text = lxb_dom_node_text_content(self.node, &text_len)
        return bytes_to_str(text[:text_len])

    @property
    def attrs(self):
        """
        List of attributes.

        :rtype: List[Attribute]
        """
        attrs = []
        if self.node == NULL or self.node.type != LXB_DOM_NODE_TYPE_ELEMENT:
            return attrs

        cdef lxb_dom_attr_t* attr = lxb_dom_element_first_attribute(<lxb_dom_element_t*>self.node)
        while attr != NULL:
            attrs.append(_attr_from_dom(attr))
            attr = attr.next

        return attrs

    cpdef bint hasattr(self, str attr_name):
        """
        hasattr(self, attr_name)
        
        Check if node has attribute.

        :param attr_name: attribute name
        :rtype: bool
        """
        if self.node == NULL or self.node.type != LXB_DOM_NODE_TYPE_ELEMENT:
            return False
        cdef bytes attr_name_bytes = attr_name.encode()
        return <bint>lxb_dom_element_has_attribute(<lxb_dom_element_t*>self.node,
                                                   <lxb_char_t*>attr_name_bytes, len(attr_name_bytes))

    cdef Attribute _getattr_impl(self, str attr_name):
        if self.node == NULL or self.node.type != LXB_DOM_NODE_TYPE_ELEMENT:
            raise ValueError('Node ist not an Element node.')

        cdef bytes attr_name_bytes = attr_name.encode()
        cdef lxb_dom_attr_t* attr = lxb_dom_element_attr_by_name(<lxb_dom_element_t*>self.node,
                                                                 <lxb_char_t*>attr_name_bytes, len(attr_name_bytes))
        if attr == NULL:
            raise KeyError(f'No such attribute: {attr_name_bytes}')

        return _attr_from_dom(attr)

    cpdef getattr(self, str attr_name, default_value=None):
        """
        getattr(self, attr_name, default_value=None)
        
        Get attribute or ``default_value``.

        :param attr_name: attribute name
        :param default_value: default value to return if attribute is unset
        """
        if not self.hasattr(attr_name):
            return default_value

        return self._getattr_impl(attr_name)

    def __getitem__(self, str attr_name):
        """
        __getitem__(self, attr_name)

        Get attribute.

        :param attr_name: attribute name
        :rtype: Attribute | None
        :raises: KeyError if no such attribute exists
        :raises: ValueError if node ist not an Element node
        """
        return self._getattr_impl(attr_name)

    def __repr__(self):
        if self.node.type == LXB_DOM_NODE_TYPE_ELEMENT:
            attrs = ' '.join(repr(a) for a in self.attrs)
            if attrs:
                attrs = ' ' + attrs
            return f'<{self.tag}{attrs}>'
        elif self.node.type == LXB_DOM_NODE_TYPE_TEXT:
            return self.text
        elif self.node.type == LXB_DOM_NODE_TYPE_DOCUMENT:
            return '[HTML Document]'
        elif self.node.type == LXB_DOM_NODE_TYPE_DOCUMENT_TYPE:
            return '<!DOCTYPE html>'
        elif self.node.type == LXB_DOM_NODE_TYPE_DOCUMENT_TYPE:
            return '<!DOCTYPE html>'

        return f'<{self.__class__.__name__} Element>'

    def __str__(self):
        return self.__repr__()


cdef class HTMLTree:
    """
    __init__(self)

    HTML DOM tree parser.
    """
    def __cinit__(self):
        self.document = lxb_html_document_create()
        if self.document == NULL:
            raise RuntimeError('Failed to allocate HTML document')

    def __dealloc__(self):
        if self.document != NULL:
            lxb_html_document_destroy(self.document)

    cpdef void parse(self, str document):
        """
        parse(self, document)
        
        Parse HTML from a Unicode string into a DOM tree.
        
        :param document: input HTML document
        :raises ValueError: if HTML parsing fails for unknown reasons
        """
        self.parse_from_bytes(document.encode('utf-8'))

    cpdef void parse_from_bytes(self, bytes document, str encoding='utf-8', str errors='ignore'):
        """
        parse_from_bytes(self, document, encoding='utf-8', errors='ignore')
        
        Decode a raw HTML byte string and parse it into a DOM tree.
        
        :param document: input byte string
        :param encoding: encoding for decoding byte string
        :param errors: decoding error policy (same as ``str.decode()``)
        :raises ValueError: if HTML parsing fails for unknown reasons
        """
        encoding = map_encoding_to_html5(encoding)
        if encoding != 'utf-8':
            document = bytes_to_str(document, encoding, errors).encode('utf-8')
        status = lxb_html_document_parse(self.document, <const lxb_char_t*>document, len(document))
        if status != LXB_STATUS_OK:
            raise ValueError('Failed to parse HTML document')

    @property
    def root(self):
        """
        HTML document root element or ``None``.

        :rtype: Node
        """
        if self.document == NULL:
            return None

        return _node_from_dom(<lxb_dom_node_t*>&self.document.dom_document.node)

    @property
    def head(self):
        """
        HTML head element or ``None``.

        :rtype: Node
        """
        if self.document == NULL:
            return None

        return _node_from_dom(<lxb_dom_node_t*>lxb_html_document_head_element(self.document))

    @property
    def body(self):
        """
        HTML document body element or ``None``.

        :rtype: Node
        """
        if self.document == NULL:
            return None

        return _node_from_dom(<lxb_dom_node_t*>lxb_html_document_body_element(self.document))