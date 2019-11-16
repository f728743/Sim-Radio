//
//  Progress.swift
//  Sim Radio
//

class Progress {
    var totalUnitCount: Int64
    var completedUnitCount: Int64 {
        didSet {
            if completedUnitCount == totalUnitCount {
                parent?.account(child: self)
            }
        }
    }
    weak var parent: Progress?
    private var children: [(portion: Int64, progress: Progress)] = []

    init(totalUnitCount: Int64) {
        self.totalUnitCount = totalUnitCount
        completedUnitCount = 0
    }

    func reset() {
        children = []
        completedUnitCount = 0
    }

    func addChild(_ child: Progress, withPendingUnitCount unitCount: Int64) {
        child.parent = self
        children.append((portion: unitCount, progress: child))
    }

    private func account(child: Progress) {
        guard let index = children.firstIndex(where: { $0.progress === child }) else {
            return
        }
        completedUnitCount += children[index].portion
        children.remove(at: index)
    }

    var fractionCompleted: Double {
        let childrenCompletedCount = children.reduce(Double(0.0)) {
            return $0 + Double($1.portion) * ($1.progress.totalUnitCount <= 0 ? 0.0 :
                $1.progress.fractionCompleted)
        }
        let completedCount = Double(completedUnitCount < 0 ? 0 : completedUnitCount) +
        childrenCompletedCount
        return completedCount <= 0.0 ? 0.0 : completedCount / Double(totalUnitCount)
    }
}

extension  Progress: CustomStringConvertible {
    private var indent: String {
        return "  " + (parent?.indent ?? "")
    }

    public var description: String {
        let indent = self.indent
        return children.reduce("Fraction completed: \(fractionCompleted) / " +
            "Completed: \(completedUnitCount) of \(totalUnitCount)" + "\n") {
            $0 + "\(indent)(portion: \($1.portion)) \($1.progress.description)"
        }
    }
}
