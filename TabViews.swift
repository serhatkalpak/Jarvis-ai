import SwiftUI

// MARK: - Geçmiş

struct ChatSection: Identifiable {
    let title: String
    let chats: [Chat]
    var id: String { title }
}

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var renameID: UUID? = nil
    @State private var renameText = ""
    @State private var showRename = false
    @State private var deleteID: UUID? = nil

    private var filtered: [Chat] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var list = store.chats.sorted(by: { $0.updated > $1.updated })
        if !q.isEmpty {
            list = list.filter { c in
                c.title.lowercased().contains(q) ||
                c.messages.contains(where: { $0.content.lowercased().contains(q) })
            }
        }
        return list
    }

    // Sabitlenenler, Bugün, Dün, Son 7 gün, Daha eski
    private var sections: [ChatSection] {
        let list = filtered
        let cal = Calendar.current
        let now = Date()

        let pinned = list.filter { $0.pinned ?? false }
        let rest = list.filter { !($0.pinned ?? false) }

        var today: [Chat] = []
        var yesterday: [Chat] = []
        var week: [Chat] = []
        var older: [Chat] = []
        for c in rest {
            if cal.isDateInToday(c.updated) {
                today.append(c)
            } else if cal.isDateInYesterday(c.updated) {
                yesterday.append(c)
            } else if let d = cal.dateComponents([.day], from: c.updated, to: now).day, d < 7 {
                week.append(c)
            } else {
                older.append(c)
            }
        }

        var out: [ChatSection] = []
        if !pinned.isEmpty { out.append(ChatSection(title: "Sabitlenenler", chats: pinned)) }
        if !today.isEmpty { out.append(ChatSection(title: "Bugün", chats: today)) }
        if !yesterday.isEmpty { out.append(ChatSection(title: "Dün", chats: yesterday)) }
        if !week.isEmpty { out.append(ChatSection(title: "Son 7 gün", chats: week)) }
        if !older.isEmpty { out.append(ChatSection(title: "Daha eski", chats: older)) }
        return out
    }

    private func preview(_ c: Chat) -> String {
        guard let last = c.messages.last(where: { $0.role == "assistant" || $0.role == "user" }) else { return "" }
        return last.content.replacingOccurrences(of: "\n", with: " ")
    }

    private func open(_ c: Chat) {
        Haptics.tap()
        store.currentID = c.id
        store.tab = 0
    }

    private func row(_ c: Chat) -> some View {
        HStack(spacing: 12) {
            Text(store.role(c.roleID)?.emoji ?? "💬")
                .font(.system(size: 22))
                .frame(width: 42, height: 42)
                .background(store.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if c.pinned ?? false {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Text(c.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if store.currentID == c.id {
                        Circle().fill(store.accent).frame(width: 8, height: 8)
                    }
                }
                Text(preview(c))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(c.updated.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { s in
                    Section(header: Text(s.title)) {
                        ForEach(s.chats) { c in
                            Button {
                                open(c)
                            } label: {
                                row(c)
                            }
                            .foregroundColor(.primary)
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.togglePin(c.id)
                                } label: {
                                    Label((c.pinned ?? false) ? "Kaldır" : "Sabitle",
                                          systemImage: (c.pinned ?? false) ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteID = c.id
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                                Button {
                                    renameID = c.id
                                    renameText = c.title
                                    showRename = true
                                } label: {
                                    Label("Ad", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    renameID = c.id
                                    renameText = c.title
                                    showRename = true
                                } label: {
                                    Label("Yeniden adlandır", systemImage: "pencil")
                                }
                                Button {
                                    store.togglePin(c.id)
                                } label: {
                                    Label((c.pinned ?? false) ? "Sabitlemeyi kaldır" : "Sabitle", systemImage: "pin")
                                }
                                ShareLink(item: store.transcript(c)) {
                                    Label("Paylaş", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    deleteID = c.id
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Sohbetlerde ara")
            .overlay {
                if sections.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: query.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(query.isEmpty ? "Henüz sohbet yok" : "Sonuç bulunamadı")
                            .font(.headline)
                        if query.isEmpty {
                            Text("İlk sorunu Sohbet sekmesinden sorabilirsin.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Geçmiş")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.tap()
                        store.newChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Yeni sohbet")
                }
            }
            .alert("Sohbeti yeniden adlandır", isPresented: $showRename) {
                TextField("Ad", text: $renameText)
                Button("Kaydet") {
                    if let id = renameID { store.rename(id, renameText) }
                }
                Button("İptal", role: .cancel) {}
            }
            .confirmationDialog("Bu sohbet silinsin mi?",
                                isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }),
                                titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    if let id = deleteID { store.deleteChat(id) }
                    deleteID = nil
                }
                Button("Vazgeç", role: .cancel) { deleteID = nil }
            }
        }
    }
}

// MARK: - Roller

struct RolesView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Role? = nil
    @State private var deleteRoleID: UUID? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Bir role dokununca o rolle yeni sohbet başlar. Köşedeki ⋯ düğmesiyle düzenleyebilir veya silebilirsin.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if store.roles.isEmpty {
                        Button {
                            store.resetRoles()
                        } label: {
                            Label("Varsayılan rolleri geri yükle", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(store.accent)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 40)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.roles) { r in
                            RoleCard(role: r,
                                     onEdit: { editing = r },
                                     onDelete: { deleteRoleID = r.id })
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Roller")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editing = Role(emoji: "✨", name: "", prompt: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni rol")
                }
            }
            .sheet(item: $editing) { r in
                RoleEditor(role: r)
                    .environmentObject(store)
            }
            .confirmationDialog("Bu rol silinsin mi?",
                                isPresented: Binding(get: { deleteRoleID != nil }, set: { if !$0 { deleteRoleID = nil } }),
                                titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    if let id = deleteRoleID { store.deleteRole(id) }
                    deleteRoleID = nil
                }
                Button("Vazgeç", role: .cancel) { deleteRoleID = nil }
            }
        }
    }
}

struct RoleCard: View {
    @EnvironmentObject var store: Store
    let role: Role
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var isActive: Bool {
        return store.activeRoleID == role.id
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Haptics.tap()
                store.activeRoleID = role.id
                store.newChat()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(role.emoji)
                        .font(.system(size: 34))
                    Text(role.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(role.prompt.isEmpty ? "Standart asistan" : role.prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isActive ? store.accent : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onEdit) {
                    Label("Düzenle", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Sil", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .padding(10)
            }
            .accessibilityLabel("Rol seçenekleri")
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Düzenle", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
        }
    }
}

struct RoleEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var role: Role

    private let emojis = ["💬", "🌍", "💻", "✍️", "📝", "🎓", "🧠", "🍳", "⚖️", "🩺", "🎨", "📈"]

    init(role: Role) {
        _role = State(initialValue: role)
    }

    private var canSave: Bool {
        return !role.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Simge ve ad")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emojis, id: \.self) { e in
                                Button {
                                    role.emoji = e
                                    Haptics.selection()
                                } label: {
                                    Text(e)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(role.emoji == e ? store.accent.opacity(0.25) : Color(.tertiarySystemBackground))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Emoji", text: $role.emoji)
                    TextField("Rol adı", text: $role.name)
                }
                Section(header: Text("Talimat"),
                        footer: Text("Yapay zekaya bu rolde nasıl davranacağını anlat. Örnek: \"Sen bir diyetisyensin...\"")) {
                    ZStack(alignment: .topLeading) {
                        if role.prompt.isEmpty {
                            Text("Örnek: Sen sabırlı bir matematik öğretmenisin...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $role.prompt)
                            .frame(minHeight: 180)
                    }
                }
            }
            .navigationTitle("Rol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        if canSave {
                            store.saveRole(role)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Ayarlar

struct SettingsRootView: View {
    @EnvironmentObject var store: Store
    @State private var showDeleteAll = false

    private let accents: [(key: String, name: String)] = [
        ("turuncu", "Turuncu"), ("mavi", "Mavi"), ("yesil", "Yeşil"), ("mor", "Mor"), ("pembe", "Pembe")
    ]

    private var themeBinding: Binding<String> {
        return Binding(get: { store.settings.theme ?? "system" }, set: { store.settings.theme = $0 })
    }

    private var maxTokensBinding: Binding<Int> {
        return Binding(get: { store.settings.maxTokens ?? 2048 }, set: { store.settings.maxTokens = $0 })
    }

    private var readyCount: Int {
        return store.settings.entries.filter {
            $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Yapay zeka")) {
                    NavigationLink {
                        ModelsView()
                    } label: {
                        HStack {
                            Label("Modeller ve API anahtarları", systemImage: "cpu")
                            Spacer()
                            Text(readyCount == 0 ? "Anahtar yok" : "\(readyCount) hazır")
                                .font(.subheadline)
                                .foregroundColor(readyCount == 0 ? .orange : .secondary)
                        }
                    }
                    NavigationLink {
                        InstructionsView()
                    } label: {
                        Label("Özel talimatlar", systemImage: "text.quote")
                    }
                    Stepper(value: maxTokensBinding, in: 256...8192, step: 256) {
                        Label("Yanıt uzunluğu: \(store.settings.maxTokens ?? 2048)", systemImage: "text.alignleft")
                    }
                }

                Section(header: Text("Görünüm")) {
                    Picker("Tema", selection: themeBinding) {
                        Text("Sistem").tag("system")
                        Text("Açık").tag("light")
                        Text("Koyu").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 14) {
                        Label("Renk", systemImage: "paintpalette")
                        Spacer()
                        ForEach(accents, id: \.key) { a in
                            let selected = (store.settings.accent ?? "turuncu") == a.key
                            Button {
                                Haptics.selection()
                                store.settings.accent = a.key
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accentColor(a.key))
                                        .frame(width: 30, height: 30)
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(a.name)
                        }
                    }
                }

                Section(header: Text("İnternet araması"),
                        footer: Text("Boş bırakırsan sadece Vikipedi'de aranır. Daha iyi sonuç için Tavily anahtarı girebilirsin.")) {
                    SecureField("Tavily API anahtarı", text: $store.settings.tavilyKey)
                }

                Section(header: Text("Veri")) {
                    HStack {
                        Text("Kayıtlı sohbet")
                        Spacer()
                        Text("\(store.chats.count)").foregroundColor(.secondary)
                    }
                    Button("Tüm sohbetleri sil", role: .destructive) { showDeleteAll = true }
                }

                Section(header: Text("Hakkında"),
                        footer: Text("Sohbetler telefonunda saklanır. API anahtarları iPhone'un güvenli alanında (Keychain) tutulur. Yazı/kod dosyaları, PDF ve resimler okunur; Word ve Excel dosyaları henüz desteklenmiyor.")) {
                    HStack {
                        Text("Sürüm")
                        Spacer()
                        Text(versionText).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .confirmationDialog("Tüm sohbetler silinsin mi?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Hepsini sil", role: .destructive) { store.deleteAllChats() }
            }
        }
    }
}

struct InstructionsView: View {
    @EnvironmentObject var store: Store

    private var binding: Binding<String> {
        return Binding(get: { store.settings.customInstructions ?? "" }, set: { store.settings.customInstructions = $0 })
    }

    var body: some View {
        Form {
            Section(footer: Text("Buraya yazdıkların her sohbette yapay zekaya iletilir. Örnek: \"Bana kısa ve basit Türkçe ile cevap ver. Kod verirken adım adım anlat.\"")) {
                ZStack(alignment: .topLeading) {
                    if binding.wrappedValue.isEmpty {
                        Text("Örnek: Kısa ve basit Türkçe ile cevap ver.")
                            .foregroundColor(Color(.placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: binding)
                        .frame(minHeight: 200)
                }
            }
            if !binding.wrappedValue.isEmpty {
                Section {
                    Button("Talimatı temizle", role: .destructive) {
                        store.settings.customInstructions = ""
                    }
                }
            }
        }
        .navigationTitle("Özel talimatlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Modeller

struct ModelRow: View {
    @EnvironmentObject var store: Store
    let entry: ProviderEntry

    private var statusColor: Color {
        if !entry.enabled { return .gray }
        if entry.key.trimmingCharacters(in: .whitespaces).isEmpty { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.model.isEmpty ? "Model adı girilmemiş" : entry.model)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if store.preferredID == entry.id {
                Text("Seçili")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(store.accent.opacity(0.15))
                    .foregroundColor(store.accent)
                    .clipShape(Capsule())
            }
        }
    }
}

struct ModelsView: View {
    @EnvironmentObject var store: Store
    @State private var showReset = false

    var body: some View {
        List {
            Section(footer: Text("Yeşil: hazır · Turuncu: anahtar yok · Gri: kapalı.\nSıra önemli: üstteki model önce denenir. Limiti dolarsa ya da hata verirse alttakine geçilir. Sıralamak için sağ üstten Düzenle'ye dokunup satırları sürükle.")) {
                ForEach(store.settings.entries) { e in
                    NavigationLink {
                        ModelEditView(id: e.id)
                    } label: {
                        ModelRow(entry: e)
                    }
                }
                .onMove { from, to in
                    store.settings.entries.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.settings.entries[$0].id }
                    for id in ids { store.removeEntry(id) }
                }
            }

            Section {
                Button {
                    store.addEntry()
                } label: {
                    Label("Yeni model / sağlayıcı ekle", systemImage: "plus.circle.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    showReset = true
                } label: {
                    Text("Model listesini varsayılana döndür")
                }
            }
        }
        .navigationTitle("Modeller")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .confirmationDialog("Tüm model ayarları ve anahtarlar silinsin mi?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Sıfırla", role: .destructive) { store.resetEntries() }
        }
    }
}

struct ModelEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var testResult: String? = nil
    @State private var testing = false

    private var index: Int? {
        return store.settings.entries.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if let i = index {
                editor(i)
            } else {
                Text("Bu model silindi.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(store.settings.entries.first(where: { $0.id == id })?.name ?? "Model")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func editor(_ i: Int) -> some View {
        let e = store.settings.entries[i]
        return Form {
            Section(header: Text("Genel")) {
                TextField("Ad", text: $store.settings.entries[i].name)
                SecureField("API anahtarı", text: $store.settings.entries[i].key)
                Toggle("Kullan", isOn: $store.settings.entries[i].enabled)
            }

            Section(header: Text("Bağlantı")) {
                Picker("Tür", selection: $store.settings.entries[i].type) {
                    ForEach(ProviderType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                TextField("Model adı", text: $store.settings.entries[i].model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Adres (base URL)", text: $store.settings.entries[i].baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section(footer: resultFooter) {
                Button {
                    testing = true
                    testResult = nil
                    let entry = e
                    Task {
                        let r = await store.test(entry)
                        testResult = r
                        testing = false
                    }
                } label: {
                    HStack {
                        Text(testing ? "Deneniyor…" : "Bağlantıyı dene")
                        if testing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(testing || e.key.isEmpty)
            }

            Section {
                Button(role: .destructive) {
                    store.removeEntry(id)
                    dismiss()
                } label: {
                    Text("Bu modeli sil")
                }
            }
        }
    }

    @ViewBuilder
    private var resultFooter: some View {
        if let r = testResult {
            Text(r)
                .foregroundColor(r.hasPrefix("✓") ? .green : .red)
        }
    }
}
