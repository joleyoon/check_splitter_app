import SwiftUI

struct ContentView: View {
    @State private var people: [Person] = [
        Person(name: "You"),
        Person(name: "Friend")
    ]
    @State private var items: [BillItem] = []
    @State private var taxText = ""
    @State private var tipPercent = 20.0
    @State private var newPersonName = ""
    @State private var newItemName = ""
    @State private var newItemPrice = ""
    @State private var scannerSource: ReceiptScannerView.Source = .camera
    @State private var showingScanner = false
    @State private var isRecognizing = false
    @State private var alertMessage: String?

    private var subtotal: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.price }
    }

    private var tax: Decimal {
        Decimal(string: taxText.replacingOccurrences(of: ",", with: ".")) ?? .zero
    }

    private var tip: Decimal {
        subtotal * Decimal(tipPercent / 100)
    }

    private var grandTotal: Decimal {
        subtotal + tax + tip
    }

    var body: some View {
        NavigationStack {
            List {
                scanSection
                peopleSection
                itemsSection
                chargesSection
                totalsSection
            }
            .navigationTitle("Check Splitter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        seedSampleCheck()
                    } label: {
                        Label("Sample", systemImage: "wand.and.stars")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ReceiptScannerView(source: scannerSource) { image in
                    recognize(image)
                }
            }
            .alert("Check Splitter", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var scanSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    scannerSource = .camera
                    showingScanner = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    scannerSource = .photoLibrary
                    showingScanner = true
                } label: {
                    Label("Choose", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if isRecognizing {
                HStack {
                    ProgressView()
                    Text("Reading check...")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Receipt")
        } footer: {
            Text("OCR finds likely line items. Review the list before settling up.")
        }
    }

    private var peopleSection: some View {
        Section("People") {
            ForEach($people) { $person in
                TextField("Name", text: $person.name)
            }
            .onDelete(perform: deletePeople)

            HStack {
                TextField("Add person", text: $newPersonName)
                    .textInputAutocapitalization(.words)
                Button {
                    addPerson()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach($items) { $item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Item", text: $item.name)
                            .font(.headline)
                        Text(Money.string(item.price))
                            .font(.headline.monospacedDigit())
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(people) { person in
                            let isAssigned = item.assignedPersonIDs.contains(person.id)
                            Button {
                                toggle(person, for: item.id)
                            } label: {
                                Label(person.name, systemImage: isAssigned ? "checkmark.circle.fill" : "circle")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .tint(isAssigned ? .green : .secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                items.remove(atOffsets: offsets)
            }

            VStack(spacing: 8) {
                TextField("Item name", text: $newItemName)
                    .textInputAutocapitalization(.words)
                HStack {
                    TextField("Price", text: $newItemPrice)
                        .keyboardType(.decimalPad)
                    Button {
                        addManualItem()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(!canAddManualItem)
                }
            }
        } header: {
            Text("Items")
        } footer: {
            if items.isEmpty {
                Text("Scan a check or add items manually.")
            } else {
                Text("Tap names under each item to split it between one or more people.")
            }
        }
    }

    private var chargesSection: some View {
        Section("Tax and Tip") {
            HStack {
                Text("Tax")
                Spacer()
                TextField("$0.00", text: $taxText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tip")
                    Spacer()
                    Text("\(Int(tipPercent.rounded()))%")
                        .monospacedDigit()
                    Text(Money.string(tip))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $tipPercent, in: 0...35, step: 1)
            }
        }
    }

    private var totalsSection: some View {
        Section {
            summaryRow("Subtotal", subtotal)
            summaryRow("Tax", tax)
            summaryRow("Tip", tip)
            summaryRow("Total", grandTotal, isBold: true)

            ForEach(personTotals) { total in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(total.person.name)
                            .font(.headline)
                        Spacer()
                        Text(Money.string(total.total))
                            .font(.headline.monospacedDigit())
                    }
                    Text("Items \(Money.string(total.subtotal)) + tax \(Money.string(total.taxShare)) + tip \(Money.string(total.tipShare))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Split")
        }
    }

    private var personTotals: [PersonTotal] {
        let itemShares = Dictionary(uniqueKeysWithValues: people.map { person in
            let subtotal = items.reduce(Decimal.zero) { running, item in
                guard item.assignedPersonIDs.contains(person.id), !item.assignedPersonIDs.isEmpty else {
                    return running
                }
                return running + item.price / Decimal(item.assignedPersonIDs.count)
            }
            return (person.id, subtotal)
        })

        return people.map { person in
            let personSubtotal = itemShares[person.id] ?? .zero
            let ratio = subtotal > 0 ? personSubtotal / subtotal : .zero
            let taxShare = tax * ratio
            let tipShare = tip * ratio
            return PersonTotal(
                person: person,
                subtotal: personSubtotal,
                taxShare: taxShare,
                tipShare: tipShare,
                total: personSubtotal + taxShare + tipShare
            )
        }
    }

    private var canAddManualItem: Bool {
        !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Decimal(string: newItemPrice.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func summaryRow(_ title: String, _ value: Decimal, isBold: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Money.string(value))
                .monospacedDigit()
        }
        .font(isBold ? .headline : .body)
    }

    private func addPerson() {
        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        people.append(Person(name: name))
        newPersonName = ""
    }

    private func deletePeople(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { people[$0].id })
        people.remove(atOffsets: offsets)
        for index in items.indices {
            items[index].assignedPersonIDs.subtract(removedIDs)
        }
    }

    private func addManualItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let priceText = newItemPrice.replacingOccurrences(of: ",", with: ".")
        guard let price = Decimal(string: priceText), price > 0 else { return }
        items.append(BillItem(name: name, price: price, assignedPersonIDs: defaultAssignees()))
        newItemName = ""
        newItemPrice = ""
    }

    private func toggle(_ person: Person, for itemID: BillItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if items[index].assignedPersonIDs.contains(person.id) {
            items[index].assignedPersonIDs.remove(person.id)
        } else {
            items[index].assignedPersonIDs.insert(person.id)
        }
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        Task {
            do {
                let recognizedItems = try await ReceiptParser.recognizeItems(in: image)
                    .map { item in
                        BillItem(name: item.name, price: item.price, assignedPersonIDs: defaultAssignees())
                    }

                await MainActor.run {
                    isRecognizing = false
                    if recognizedItems.isEmpty {
                        alertMessage = "No line items were found. Try a clearer photo or add items manually."
                    } else {
                        items = recognizedItems
                    }
                }
            } catch {
                await MainActor.run {
                    isRecognizing = false
                    alertMessage = "Could not read the check: \(error.localizedDescription)"
                }
            }
        }
    }

    private func defaultAssignees() -> Set<Person.ID> {
        Set(people.map(\.id))
    }

    private func seedSampleCheck() {
        items = [
            BillItem(name: "Margherita Pizza", price: 18.00, assignedPersonIDs: defaultAssignees()),
            BillItem(name: "Caesar Salad", price: 12.50, assignedPersonIDs: people.prefix(1).map(\.id).reduce(into: Set<Person.ID>()) { $0.insert($1) }),
            BillItem(name: "Pasta", price: 21.00, assignedPersonIDs: people.suffix(1).map(\.id).reduce(into: Set<Person.ID>()) { $0.insert($1) })
        ]
        taxText = "4.12"
        tipPercent = 20
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ContentView()
}
