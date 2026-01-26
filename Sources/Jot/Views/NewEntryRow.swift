import SwiftUI

struct NewEntryRow: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onCommit: () -> Void
    var useCheckboxSpacing: Bool = false

    private let leadingWidth: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Color.clear
                .frame(width: useCheckboxSpacing ? leadingWidth : 0, height: 1)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .foregroundStyle(Color.black)
                .focused(focus)
                .onSubmit(onCommit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
