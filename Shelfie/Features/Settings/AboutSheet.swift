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
            // Logo, name and version pinned at the top, so the list below always has room for every link.
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shelfie")
                    .font(.title2.bold())
                Text(version)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Your reading, on a 3D bookshelf.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .combine)
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
