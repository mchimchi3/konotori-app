import SwiftUI
import SafariServices

// MARK: - SafariView

/// UIViewControllerRepresentable wrapping SFSafariViewController.
/// Usage:
///   .sheet(isPresented: $showSafari) {
///       SafariView(url: productURL)
///   }
struct SafariView: UIViewControllerRepresentable {

    let url: URL
    var tintColor: UIColor = .systemPink
    var dismissButtonStyle: SFSafariViewController.DismissButtonStyle = .close
    var entersReaderIfAvailable: Bool = false
    var barCollapsingEnabled: Bool = true

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = entersReaderIfAvailable
        configuration.barCollapsingEnabled = barCollapsingEnabled

        let safariVC = SFSafariViewController(url: url, configuration: configuration)
        safariVC.preferredControlTintColor = tintColor
        safariVC.dismissButtonStyle = dismissButtonStyle
        safariVC.delegate = context.coordinator
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No dynamic updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // Dismissal is handled automatically by the sheet binding
        }

        func safariViewController(
            _ controller: SFSafariViewController,
            didCompleteInitialLoad didLoadSuccessfully: Bool
        ) {
            if !didLoadSuccessfully {
                print("[SafariView] Initial load failed")
            }
        }
    }
}

// MARK: - View Extension for Convenience

extension View {
    /// Presents a SafariView as a sheet when `url` is non-nil.
    func safariSheet(url: Binding<URL?>) -> some View {
        sheet(item: Binding(
            get: { url.wrappedValue.map { IdentifiableURL(url: $0) } },
            set: { item in url.wrappedValue = item?.url }
        )) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}

// MARK: - IdentifiableURL Helper

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
