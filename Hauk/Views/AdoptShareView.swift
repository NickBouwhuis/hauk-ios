import SwiftUI

struct AdoptShareView: View {
    @EnvironmentObject var sharingManager: SharingManager
    @Binding var isPresented: Bool
    @State private var shareId: String = ""
    @State private var nickname: String = ""
    @State private var isAdopting: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Merge Share")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the share ID or URL of a solo share to merge it into your group share.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share ID or URL")
                            .font(.headline)
                        
                        TextField("Enter share ID or paste URL", text: $shareId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: shareId) { _, newValue in
                                // Extract share ID from URL if pasted
                                if let extractedId = extractShareId(from: newValue) {
                                    shareId = extractedId
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nickname for this user")
                            .font(.headline)
                        
                        TextField("Enter nickname", text: $nickname)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: adoptShare) {
                        HStack {
                            if isAdopting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isAdopting ? "Merging..." : "Merge Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAdopt ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!canAdopt || isAdopting)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Merge Share")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
    
    private var canAdopt: Bool {
        !shareId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func adoptShare() {
        guard canAdopt else { return }
        
        isAdopting = true
        errorMessage = nil
        
        Task {
            do {
                try await sharingManager.adoptShare(
                    shareId: shareId.trimmingCharacters(in: .whitespacesAndNewlines),
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAdopting = false
                }
            }
        }
    }
    
    private func extractShareId(from input: String) -> String? {
        // Try to extract share ID from various URL formats
        let patterns = [
            #"/([a-zA-Z0-9\-_]+)/?$"#,  // Basic share ID at end of URL
            #"share/([a-zA-Z0-9\-_]+)"#, // Share ID after /share/
            #"^([a-zA-Z0-9\-_]+)$"#      // Just the share ID itself
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
               let range = Range(match.range(at: 1), in: input) {
                return String(input[range])
            }
        }
        
        return nil
    }
}

#Preview {
    AdoptShareView(isPresented: .constant(true))
        .environmentObject(SharingManager.shared)
}

