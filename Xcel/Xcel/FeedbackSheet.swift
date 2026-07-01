import SwiftUI
import MessageUI

// A lighter-weight, in-app alternative to a bare mailto link: pick a category,
// write freely against a prompt tailored to it, then send. The message is
// rendered into an in-app Mail compose sheet (MFMailComposeViewController) so
// the user never leaves the app to Mail.app; only if no mail account is
// configured on the device does it fall back to the old mailto behavior.
enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug, uiux, feature, judge, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug:     return "Bug"
        case .uiux:    return "UI / UX"
        case .feature: return "Feature idea"
        case .judge:   return "AI judge"
        case .other:   return "Other"
        }
    }

    var icon: String {
        switch self {
        case .bug:     return "ladybug"
        case .uiux:    return "paintbrush"
        case .feature: return "lightbulb"
        case .judge:   return "gavel"
        case .other:   return "ellipsis.bubble"
        }
    }

    // Shown above the text field to coach the user toward detail specific to
    // the category they picked - vague "it's buggy" feedback is much less
    // useful than "the noon lock triggered early on Game 4."
    var prompt: String {
        switch self {
        case .bug:     return "What broke? What were you doing right before it happened?"
        case .uiux:    return "What felt clunky, confusing, or off - and on which screen?"
        case .feature: return "What do you wish Xcel could do?"
        case .judge:   return "What did the judge get wrong (or really right)? Mention the day if you remember it."
        case .other:   return "What's on your mind?"
        }
    }
}

struct FeedbackSheet: View {
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var category: FeedbackCategory?
    @State private var detail = ""
    @State private var showMailCompose = false

    private var canSend: Bool {
        category != nil && detail.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        categoryPicker
                        if let category {
                            detailField(for: category)
                        }
                    }
                    .padding(24)
                }
                sendButton
            }
        }
        .dismissKeyboardOnScroll()
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(subject: mailSubject, body: mailBody, recipient: "xtinctai@outlook.com") {
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SEND FEEDBACK")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Talk to us")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S THIS ABOUT?")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.35))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(FeedbackCategory.allCases) { cat in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { category = cat }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                            Text(cat.label)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(category == cat ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(category == cat ? accent : Color(white: 0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func detailField(for category: FeedbackCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.prompt.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Color(white: 0.35))
                .fixedSize(horizontal: false, vertical: true)

            TextField("Be as specific as you want - more detail helps more.", text: $detail, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(6...14)
                .padding(14)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            Text(canSend ? "Send" : "Pick a topic and write a bit more")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(canSend ? .black : Color(white: 0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canSend ? accent : Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSend)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var mailSubject: String {
        "Xcel Feedback - \(category?.label ?? "General")"
    }

    private var mailBody: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return """
        Category: \(category?.label ?? "General")

        \(detail.trimmingCharacters(in: .whitespacesAndNewlines))

        - - -
        Xcel \(version) (\(build))
        iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)
        """
    }

    private func send() {
        guard canSend else { return }
        guard MFMailComposeViewController.canSendMail() else {
            var comps = URLComponents()
            comps.scheme = "mailto"
            comps.path = "xtinctai@outlook.com"
            comps.queryItems = [
                URLQueryItem(name: "subject", value: mailSubject),
                URLQueryItem(name: "body", value: mailBody),
            ]
            if let url = comps.url { openURL(url) }
            dismiss()
            return
        }
        showMailCompose = true
    }
}

// Thin SwiftUI wrapper around MFMailComposeViewController so the compose sheet
// stays in-app instead of switching out to Mail.
private struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String
    let onSent: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.setToRecipients([recipient])
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSent: onSent) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onSent: () -> Void
        init(onSent: @escaping () -> Void) { self.onSent = onSent }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                if result == .sent { self.onSent() }
            }
        }
    }
}
