import SwiftUI

struct ArchiveView: View {
    @State private var store  = ArchiveStore.shared
    @State private var search = ""
    @State private var grid   = false
    @State private var showAdd    = false
    @State private var showArch   = false
    @State private var showPaywall = false
    @State private var filter: Person.Status? = nil
    @State private var appeared = false
    @State private var replayTutorial = false

    var list: [Person] {
        var r = store.active
        if !search.isEmpty { r = r.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        if let f = filter { r = r.filter { $0.status == f } }
        return r
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Search
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.rwTextMuted).font(.system(size: 15, design: .rounded))
                        TextField("Search...", text: $search).font(RWF.body()).foregroundColor(.rwTextPrimary)
                        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.rwTextMuted) } }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))

                    Button { withAnimation { grid.toggle() } } label: {
                        Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.rwTextSecondary)
                            .frame(width: 40, height: 40).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                    }
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 8)

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(label: "All", sel: filter == nil) { filter = nil }
                        ForEach(Person.Status.allCases.filter { $0.isActive }, id: \.rawValue) { s in
                            Chip(label: s.rawValue, sel: filter == s, color: s.color) {
                                filter = filter == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, SP.lg)
                }
                .padding(.bottom, 8)

                RWLine()

                if store.active.isEmpty {
                    RWEmptyState(
                        icon: "person.2.fill",
                        title: "No connections yet",
                        subtitle: "Add people you're talking to and track every conversation.",
                        cta: "Add First Connection",
                        ctaIcon: "plus",
                        onCTA: { showAdd = true }
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        if grid {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(list) { p in
                                    NavigationLink(destination: ContactDetailView(p: p)) { GridCard(p: p) }
                                }
                            }
                            .padding(.horizontal, SP.lg).padding(.top, 12).padding(.bottom, 100)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(list.enumerated()), id: \.element.id) { index, p in
                                    NavigationLink(destination: ContactDetailView(p: p)) { RowCard(p: p) }
                                        .padding(.horizontal, SP.lg)
                                        .staggerAppear(index, appeared: appeared)
                                }
                            }
                            .padding(.top, 12).padding(.bottom, 100)
                            .onAppear { appeared = true }
                        }
                    }
                    .refreshable { await store.load() }
                }
            }
            .rwBG()
            .navigationTitle("The Archive")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TutorialReplayButton(id: .archive, forceShow: $replayTutorial)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !store.archived.isEmpty {
                            Button { showArch = true } label: {
                                Image(systemName: "archivebox").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.rwTextSecondary)
                            }
                        }
                        Button { if StoreManager.shared.canAddToArchive() { showAdd = true } else { showPaywall = true } } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22, design: .rounded)).foregroundColor(.rwAccent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddContactChoiceSheet { _ in }
        }
        .sheet(isPresented: $showArch) { ArchivedView() }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .archiveLimit) }
        .tutorial(.archive, forceShow: $replayTutorial)
    }
}

struct Chip: View {
    let label: String; let sel: Bool; var color: Color = .rwAccent; let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            Text(label).font(RWF.cap(12))
                .foregroundColor(sel ? .white : .rwTextSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(sel ? color : Color.rwCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(sel ? Color.clear : Color.rwBorder, lineWidth: 1))
                .shadow(color: sel ? color.opacity(0.25) : .clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3), value: sel)
    }
}

struct RowCard: View {
    let p: Person
    private var photoCount: Int { ContactPhotoStore.shared.intelPhotoCount(contactID: p.id) }
    var body: some View {
        HStack(spacing: 14) {
            ContactAvatar(person: p, size: 52, showFavoriteBadge: true, version: 0)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(p.name).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                    if let a = p.age { Text("\(a)").font(RWF.cap(12)).foregroundColor(.rwTextMuted) }
                }
                HStack(spacing: 6) {
                    Tag(t: p.status.rawValue, c: p.status.color)
                    if p.isGoingCold {
                        Tag(t: "Going cold", c: Color(hex: "5B8DEF"))
                    } else {
                        Tag(t: p.source.rawValue, c: p.source.color)
                    }
                    if photoCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.fill").font(.system(size: 9, weight: .medium, design: .rounded))
                            Text("\(photoCount)").font(RWF.micro())
                        }
                        .foregroundColor(Color(hex: "9B59B6"))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color(hex: "9B59B6").opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.rwTextMuted)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(p.isGoingCold ? Color(hex: "5B8DEF").opacity(0.35) : Color.rwBorder,
                        lineWidth: 1)
        )
        .shadow(color: p.source.color.opacity(0.08), radius: 14, x: 0, y: 4)
    }
}

struct Tag: View {
    let t: String; let c: Color
    var body: some View {
        Text(t).font(RWF.micro()).foregroundColor(c)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(c.opacity(0.12)).clipShape(Capsule())
    }
}

struct GridCard: View {
    let p: Person
    private var photoCount: Int { ContactPhotoStore.shared.intelPhotoCount(contactID: p.id) }
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ContactAvatar(person: p, size: 78, showFavoriteBadge: p.isFavorite)
                    .padding(.top, 6)
                if photoCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.fill").font(.system(size: 8, weight: .medium, design: .rounded))
                        Text("\(photoCount)").font(RWF.micro())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color(hex: "9B59B6"))
                    .clipShape(Capsule())
                    .offset(x: 8, y: 0)
                }
            }
            VStack(spacing: 4) {
                Text(p.name)
                    .font(RWF.head(14))
                    .foregroundColor(.rwTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: p.status.icon).font(.system(size: 9, weight: .medium, design: .rounded))
                    Text(p.status.rawValue).font(RWF.micro()).lineLimit(1)
                }
                .foregroundColor(p.status.color)
                if p.isGoingCold {
                    Label("Going cold", systemImage: "thermometer.snowflake")
                        .font(RWF.micro())
                        .foregroundColor(Color(hex: "5B8DEF"))
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(SP.sm)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: p.source.color.opacity(0.08), radius: 12, x: 0, y: 3)
    }
}

// MARK: - Add Person

struct AddView: View {
    @Environment(\.dismiss) var dismiss
    @State private var store = ArchiveStore.shared
    @State private var p = Person()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.xl) {
                    OBHead(step: "New Connection", title: "Who are you\nconnecting with?", sub: "Add what you know.")

                    VStack(spacing: 14) {
                        SF(label: "Name",       icon: "person.fill",   ph: "Their first name",  text: $p.name)
                        SF(label: "Occupation", icon: "briefcase.fill", ph: "What do they do?",  text: $p.occupation)
                        SF(label: "Location",   icon: "location.fill",  ph: "City or area",      text: $p.location)
                        SF(label: "Phone",      icon: "phone.fill",     ph: "Phone number",      text: $p.phone)
                        SF(label: "Instagram",  icon: "camera.fill",    ph: "@handle",           text: $p.instagram)
                        SF(label: "Notes",      icon: "note.text",      ph: "Anything to remember...", text: $p.notes)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Where did you meet?", systemImage: "map.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 8) {
                                ForEach(Person.Source.allCases, id: \.rawValue) { s in
                                    Button { p.source = s } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: s.icon).font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundColor(p.source == s ? .white : s.color)
                                                .frame(width: 36, height: 36)
                                                .background(p.source == s ? s.color : s.color.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                                            Text(s.rawValue).font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundColor(p.source == s ? .rwTextPrimary : .rwTextMuted)
                                                .lineLimit(1).minimumScaleFactor(0.7)
                                        }
                                        .padding(8)
                                        .background(p.source == s ? s.color.opacity(0.1) : Color.rwCard)
                                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                                        .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(p.source == s ? s.color.opacity(0.4) : Color.rwBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(SBS())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SP.xl)

                    RWButton("Save Connection", icon: "checkmark") {
                        p.lastSpoke = Date()
                        store.add(p)
                        dismiss()
                    }
                    .disabled(p.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(p.name.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, SP.xl).padding(.bottom, 48)
                }
                .padding(.top, 20)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary) } }
        }
    }
}

struct SF: View {
    let label: String; let icon: String; let ph: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon).font(RWF.cap()).foregroundColor(.rwTextMuted)
            TextField("", text: $text, prompt: Text(ph).foregroundColor(.rwTextMuted))
                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                .padding(SP.md).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                .autocorrectionDisabled()
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @State var p: Person
    @State private var store = ArchiveStore.shared
    @State private var showEdit = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(p.source.color.opacity(0.2)).frame(width: 90, height: 90)
                        Text(p.initial).font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(p.source.color)
                    }.padding(.top, 12)
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(p.name).font(RWF.title(24)).foregroundColor(.rwTextPrimary)
                            if let a = p.age { Text("\(a)").font(RWF.body()).foregroundColor(.rwTextMuted) }
                        }
                        if !p.occupation.isEmpty || !p.location.isEmpty {
                            Text([p.occupation, p.location].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        }
                        HStack(spacing: 8) {
                            Tag(t: p.source.rawValue, c: p.source.color)
                            Menu {
                                ForEach(Person.Status.allCases, id: \.rawValue) { s in
                                    Button { p.status = s; store.update(p) } label: { Label(s.rawValue, systemImage: s.icon) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: p.status.icon).font(.system(size: 10, weight: .semibold, design: .rounded))
                                    Text(p.status.rawValue).font(RWF.micro())
                                    Image(systemName: "chevron.down").font(.system(size: 8, design: .rounded))
                                }
                                .foregroundColor(p.status.color).padding(.horizontal, 9).padding(.vertical, 4)
                                .background(p.status.color.opacity(0.12)).clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SP.lg)

                // Rating
                RWCard {
                    HStack {
                        Text("Rating").font(RWF.head()).foregroundColor(.rwTextPrimary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { i in
                                Button { p.rating = i; store.update(p) } label: {
                                    Image(systemName: i <= p.rating ? "star.fill" : "star")
                                        .font(.system(size: 22, design: .rounded)).foregroundColor(i <= p.rating ? .rwGold : .rwTextMuted)
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    }
                }
                .padding(.horizontal, SP.lg)

                // Contact
                if !p.phone.isEmpty || !p.instagram.isEmpty {
                    RWCard {
                        VStack(spacing: 10) {
                            if !p.phone.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "phone.fill").foregroundColor(.rwSuccess)
                                        .frame(width: 32, height: 32).background(Color.rwSuccess.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                                    Text(p.phone).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    Spacer()
                                }
                            }
                            if !p.instagram.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "camera.fill").foregroundColor(.rwAccent)
                                        .frame(width: 32, height: 32).background(Color.rwAccent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                                    Text("@\(p.instagram)").font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SP.lg)
                }

                if !p.notes.isEmpty {
                    RWCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes").font(RWF.head()).foregroundColor(.rwTextPrimary)
                            Text(p.notes).font(RWF.body()).foregroundColor(.rwTextSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, SP.lg)
                }

                RWButton("Archive \(p.name)", icon: "archivebox.fill", style: .ghost) {
                    store.archive(p); dismiss()
                }
                .padding(.horizontal, SP.lg)

                Spacer().frame(height: 80)
            }
        }
        .rwBG()
        .navigationTitle(p.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }.foregroundColor(.rwAccent)
            }
        }
        .sheet(isPresented: $showEdit) { EditView(p: $p) }
        .onDisappear { store.update(p) }
    }
}

struct EditView: View {
    @Binding var p: Person
    @State private var store = ArchiveStore.shared
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    SF(label: "Name",       icon: "person.fill",   ph: "Name",       text: $p.name)
                    SF(label: "Occupation", icon: "briefcase.fill", ph: "Occupation", text: $p.occupation)
                    SF(label: "Location",   icon: "location.fill",  ph: "Location",   text: $p.location)
                    SF(label: "Phone",      icon: "phone.fill",     ph: "Phone",      text: $p.phone)
                    SF(label: "Instagram",  icon: "camera.fill",    ph: "@handle",    text: $p.instagram)
                    SF(label: "Notes",      icon: "note.text",      ph: "Notes",      text: $p.notes)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { store.update(p); dismiss() }.font(RWF.med()).foregroundColor(.rwAccent)
                }
            }
        }
    }
}

struct ArchivedView: View {
    @State private var store = ArchiveStore.shared
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.archived) { p in
                        HStack(spacing: 14) {
                            ContactAvatar(person: p, size: 52, showFavoriteBadge: true, version: 0)
                            Text(p.name).font(RWF.head(16)).foregroundColor(.rwTextSecondary)
                            Spacer()
                            Button("Restore") { store.restore(p) }
                                .font(RWF.cap()).foregroundColor(.rwAccent)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.rwAccent.opacity(0.1)).clipShape(Capsule())
                        }
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                        .padding(.horizontal, SP.lg)
                    }
                }
                .padding(.top, 16).padding(.bottom, 60)
            }
            .rwBG()
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}
