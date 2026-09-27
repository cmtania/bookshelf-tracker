import SwiftUI

/// "About Shelfie": the logo, name and version at the top, then help, legal pages and support.
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                            .accessibilityHidden(true)
                        Text("Shelfie")
                            .font(.title.bold())
                        Text(version)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Your reading, on a 3D bookshelf.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color.clear)

                Section {
                    linkRow("Help & FAQ", systemImage: "questionmark.circle", destination: AppLinks.support)
                    linkRow("Privacy Policy", systemImage: "hand.raised", destination: AppLinks.privacy)
                    linkRow("Terms of Service", systemImage: "doc.text", destination: AppLinks.termsOfService)
                }

                Section {
                    Link(destination: AppLinks.supportEmail) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact support")
                                    .foregroundStyle(.primary)
                                Text("tania.dev.ph@gmail.com")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Made by Christian Tania. © 2026 Shelfie.")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func linkRow(_ title: String, systemImage: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
