import SwiftUI

struct ShareModeSelectionView: View {
    @Binding var selectedMode: ShareMode
    @Binding var nickname: String
    @Binding var groupPin: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sharing Mode")
                .font(.headline)
            
            // Dropdown picker for sharing mode
            Picker("Sharing Mode", selection: $selectedMode) {
                ForEach(ShareMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            // Show additional fields based on selected mode
            if selectedMode.isGroupType {
                VStack(spacing: 12) {
                    Divider()
                    
                    TextField("Nickname", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    if selectedMode == .joinGroup {
                        TextField("Group PIN", text: $groupPin)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: groupPin) { newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    groupPin = String(newValue.prefix(6))
                                }
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedMode)
            }
            
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


#Preview {
    ShareModeSelectionView(
        selectedMode: .constant(.createAlone),
        nickname: .constant(""),
        groupPin: .constant("")
    )
    .padding()
}
