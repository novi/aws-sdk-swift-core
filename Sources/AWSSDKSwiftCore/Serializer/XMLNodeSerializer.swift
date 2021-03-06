//
//  XMLNodeSerializer.swift
//  AWSSDKSwift
//
//  Created by Yuki Takei on 2017/04/07.
//
//

import Foundation

private func dquote(_ str: String) -> String {
    if str.isEmpty {
        return ""
    }
    
    if str.first == "\"" && str.last == "\"" {
        return str
    }
    
    return "\"\(str)\""
}

private func formatAsJSONValue(_ str: String) -> String {
    if let number = Double(str) {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return Int(number).description
        } else {
            return number.description
        }
    } else if ["false", "true"].contains(where: { $0 == str.lowercased() }) {
        return str.lowercased()
    } else if str == "null" {
        return str
    } else {
        return dquote(str)
    }
}

public class XMLNodeSerializer {
    
    let node: XMLNode
    
    public init(node: XMLNode) {
        self.node = node
    }
    
    public func serializeToXML() -> String {
        var xmlStr = ""
        
        func _serialize(nodeTree: [XMLNode]) {
            for node in nodeTree {
                
                var attr = ""
                if !node.attributes.isEmpty {
                    attr = " " + node.buildAttributes()
                }
                
                if node.hasArrayValue() {
                    for value in node.values {
                        xmlStr += "<\(node.elementName)\(attr)>\(value)</\(node.elementName)>"
                    }
                }
                
                if node.hasSingleValue() {
                    xmlStr += "<\(node.elementName)\(attr)>\(node.values[0])</\(node.elementName)>"
                }
                
                if node.hasChildren() {
                    xmlStr += "<\(node.elementName)\(attr)>"
                    _serialize(nodeTree: node.children)
                    xmlStr += "</\(node.elementName)>"
                }
            }
        }
        
        _serialize(nodeTree: [node])
        
        return xmlStr
    }
    
    public func serializeToJSON() -> String {
        
        func _serialize(nodeTree: [XMLNode]) -> String {
            var jsonStr = ""
            
            for (index, node) in nodeTree.enumerated() {
                jsonStr += dquote(node.elementName) + ":"
                
                if node.hasArrayValue() {
                    jsonStr += "[" +  node.values.map({ formatAsJSONValue($0) }).joined(separator: ",") + "]"
                    if nodeTree.count-index > 1 { jsonStr+="," }
                }
                
                if node.hasSingleValue() {
                    jsonStr += formatAsJSONValue(node.values[0])
                    if nodeTree.count-index > 1 { jsonStr+="," }
                }
                
                if node.hasChildren() {
                    var grouped: [String: [XMLNode]] = [:]
                    node.children.forEach {
                        if grouped[$0.elementName] == nil { grouped[$0.elementName] = [] }
                        grouped[$0.elementName]?.append($0)
                    }
                    jsonStr += "{"
                    
                    let arrayNodes = grouped.filter({ $0.value.count > 1 })
                    let keys = arrayNodes.map({ $0.key })
                    let newChildren = node.children.filter({ !keys.contains($0.elementName) })
                    
                    for (element, nodes) in arrayNodes {
                        jsonStr += "\(dquote(element)):["
                        if nodes.isStructedArray() {
                            jsonStr += (nodes.map({ "{" + _serialize(nodeTree: $0.children) + "}"  }).joined(separator: ","))
                        } else {
                            jsonStr += nodes.flatMap({ $0.values }).map({ formatAsJSONValue($0) }).joined(separator: ",")
                        }
                        jsonStr += "]"
                        if newChildren.count > 0 { jsonStr += "," }
                    }
                    
                    jsonStr += _serialize(nodeTree: newChildren)
                    jsonStr += "}"
                    if nodeTree.count-1-index > 0 { jsonStr += "," }
                }
            }
            
            return jsonStr
        }
        
        return ("{" + _serialize(nodeTree: [node]) + "}").replacingOccurrences(of: "\n", with: "", options: .regularExpression)
        
    }
}

extension Collection where Self.Iterator.Element == XMLNode {
    func isStructedArray() -> Bool {
        if let hasChildren = self.first?.hasChildren() {
            return hasChildren
        }
        return false
    }
}
