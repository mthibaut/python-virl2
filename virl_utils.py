from lxml import etree

class NodeError(NameError):
    pass

class EntryError(NameError):
    pass

def get_entry_by_key(root, key):
    for element in root.iter():
        if element.tag == '{http://www.cisco.com/VIRL}entry' and \
           element.get('key') == key:
            return element
    raise EntryError('Key "%s" not found in xml tree' % key)

def get_entrytext_by_key(root, key):
    return str.strip(get_entry_by_key(root, key).text)

def get_node_entry_by_key(root, node, key):
    for element in root.iter():
        if element.tag == '{http://www.cisco.com/VIRL}node' and \
           element.get('name') == node:
               return(get_entrytext_by_key(element, key))
    raise NodeError('Node "%s" not found in xml tree' % node)

def get_file_node_entry_by_key(file, node, key):
    tree = etree.parse(file)
    return get_node_entry_by_key(tree.getroot(), node, key)

def get_file_entry_by_key(file, key):
    tree = etree.parse(file)
    return get_entrytext_by_key(tree.getroot(), key)

def get_nodes_xml(root):
    nodes = []
    for element in root.iter():
        if element.tag == '{http://www.cisco.com/VIRL}node':
            nodes.append(element)
    return nodes

def get_nodes(root):
    names = []
    for node in get_nodes_xml(root):
        names.append(node.get('name'))
    return names

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

