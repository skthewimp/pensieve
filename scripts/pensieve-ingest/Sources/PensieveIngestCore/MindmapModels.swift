import Foundation

public struct MindmapState: Codable {
    public var version: Int
    public var lastUpdated: String
    public var root: MindmapNode

    public init(version: Int, lastUpdated: String, root: MindmapNode) {
        self.version = version
        self.lastUpdated = lastUpdated
        self.root = root
    }
}

public struct MindmapNode: Codable {
    public var id: String
    public var label: String
    public var noteCount: Int
    public var importance: Int
    public var summary: String
    public var sourcePages: [String]
    public var children: [MindmapNode]

    public init(id: String, label: String, noteCount: Int, importance: Int,
                summary: String, sourcePages: [String], children: [MindmapNode]) {
        self.id = id
        self.label = label
        self.noteCount = noteCount
        self.importance = importance
        self.summary = summary
        self.sourcePages = sourcePages
        self.children = children
    }
}

public struct MindmapPatch: Codable {
    public var operations: [NodeOp]
    public var insights: [Insight]

    public init(operations: [NodeOp], insights: [Insight]) {
        self.operations = operations
        self.insights = insights
    }
}

public enum NodeOp: Codable {
    case add(parentId: String, node: MindmapNode)
    case update(id: String, importance: Int?, summary: String?, label: String?)
    case move(id: String, newParentId: String)
    case merge(fromId: String, intoId: String)
    case remove(id: String)
}

public struct Insight: Codable {
    public enum Kind: String, Codable {
        case tooDeep, tooShallow, shouldGoDeeper, tooBroad
    }

    public var kind: Kind
    public var nodeId: String
    public var message: String

    public init(kind: Kind, nodeId: String, message: String) {
        self.kind = kind
        self.nodeId = nodeId
        self.message = message
    }
}

public struct MindmapStats {
    public let nodesTotal: Int
    public let opsApplied: Int
    public let insightsCount: Int
    public let inputTokens: Int
    public let outputTokens: Int

    public init(nodesTotal: Int, opsApplied: Int, insightsCount: Int,
                inputTokens: Int, outputTokens: Int) {
        self.nodesTotal = nodesTotal
        self.opsApplied = opsApplied
        self.insightsCount = insightsCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
