struct GitHubRepository: Decodable {
    let name: String
    let full_name: String
    let archived: Bool
    let disabled: Bool
}
