import Foundation

struct ExecutionReceipt: Codable, Sendable {
    var taskID: String
    var callID: String
    var tool: String
    var result: JSONObject
    var createdAt = Date()
}

actor ExecutionReceiptStore {
    private let files: FileStore
    private let name = "receipts.json"
    init(files: FileStore) { self.files = files }
    func get(taskID: String, callID: String) async -> ExecutionReceipt? { (try? await files.load([ExecutionReceipt].self, from: name, fallback: []))?.first { $0.taskID == taskID && $0.callID == callID } }
    func put(_ receipt: ExecutionReceipt) async {
        var all = (try? await files.load([ExecutionReceipt].self, from: name, fallback: [])) ?? []
        all.removeAll { $0.taskID == receipt.taskID && $0.callID == receipt.callID }; all.append(receipt)
        if all.count > 2_000 { all = Array(all.suffix(2_000)) }; try? await files.save(all, to: name)
    }
}
