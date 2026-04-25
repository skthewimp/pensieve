import Foundation

public enum MindmapPatchApplier {
    public static func apply(_ patch: MindmapPatch, to state: MindmapState) throws -> MindmapState {
        var root = state.root
        for op in patch.operations {
            root = applyOp(op, to: root)
        }
        return MindmapState(version: state.version, lastUpdated: state.lastUpdated, root: root)
    }

    private static func applyOp(_ op: NodeOp, to node: MindmapNode) -> MindmapNode {
        switch op {
        case .add(let parentId, let newNode):
            return mutate(node) { n in
                if n.id == parentId { n.children.append(newNode) }
            }
        case .update(let id, let imp, let summary, let label):
            return mutate(node) { n in
                if n.id == id {
                    if let imp = imp { n.importance = imp }
                    if let summary = summary { n.summary = summary }
                    if let label = label { n.label = label }
                }
            }
        case .move(let id, let newParentId):
            guard let (detached, withoutId) = detach(id: id, from: node) else { return node }
            return mutate(withoutId) { n in
                if n.id == newParentId { n.children.append(detached) }
            }
        case .merge(let fromId, let intoId):
            guard let (from, withoutFrom) = detach(id: fromId, from: node) else { return node }
            return mutate(withoutFrom) { n in
                if n.id == intoId {
                    n.children.append(contentsOf: from.children)
                    n.noteCount += from.noteCount
                }
            }
        case .remove(let id):
            return detach(id: id, from: node)?.1 ?? node
        }
    }

    private static func mutate(_ node: MindmapNode, _ f: (inout MindmapNode) -> Void) -> MindmapNode {
        var copy = node
        f(&copy)
        copy.children = copy.children.map { mutate($0, f) }
        return copy
    }

    /// Returns (detached subtree, parent tree with subtree removed) if found.
    private static func detach(id: String, from node: MindmapNode) -> (MindmapNode, MindmapNode)? {
        if let idx = node.children.firstIndex(where: { $0.id == id }) {
            var copy = node
            let removed = copy.children.remove(at: idx)
            return (removed, copy)
        }
        for (i, child) in node.children.enumerated() {
            if let (removed, newChild) = detach(id: id, from: child) {
                var copy = node
                copy.children[i] = newChild
                return (removed, copy)
            }
        }
        return nil
    }
}
