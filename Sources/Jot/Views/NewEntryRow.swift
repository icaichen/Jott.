import SwiftUI

struct NewEntryRow: View {
    @EnvironmentObject private var store: JotStore
    @Binding var text: String
    var focusedField: FocusState<FocusField?>.Binding
    var onCommit: () -> Void
    var useCheckboxSpacing: Bool = false
    var onMoveUp: () -> Void

    private let leadingWidth: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Color.clear
                .frame(width: useCheckboxSpacing ? leadingWidth : 0, height: 1)

            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: store.contentFontSize))
                .foregroundStyle(Color.black)
                .focused(focusedField, equals: .newEntry)
                .onSubmit(onCommit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onKeyPress(.upArrow) {
            onMoveUp()
            return .handled
        }
        .padding(.vertical, 2)
    }
}
