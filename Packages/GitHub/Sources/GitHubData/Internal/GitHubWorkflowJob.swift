struct GitHubWorkflowJob: Decodable {
    let id: Int64
    let status: String
    let labels: [String]
}
