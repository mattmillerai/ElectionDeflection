import SwiftUI

// MARK: - View model

/// Owns the user's custom filter rules for the main app. The only writer of
/// `SharedDataManager.userFilterRules`; every mutation is validated here (not just in
/// the UI) so an invalid or pathological pattern can never reach the extension.
/// Rules are kept but read-only when Pro has lapsed.
@MainActor
final class MyFiltersViewModel: ObservableObject {
    @Published private(set) var rules: [UserFilterRule]

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager = .shared) {
        self.dataManager = dataManager
        self.rules = dataManager.userFilterRules
    }

    var canAddMore: Bool { rules.count < UserFilterRuleValidator.maxRules }

    /// Validates and saves (adds, or replaces the rule with the same id). Returns the
    /// problem, or nil on success. Rejects writes when the user isn't Pro.
    @discardableResult
    func save(_ rule: UserFilterRule, isProTier: Bool) -> UserFilterRuleError? {
        guard isProTier else { return nil }
        var candidate = rule
        candidate.pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = UserFilterRuleValidator.validate(candidate, existing: rules) { return error }
        if let index = rules.firstIndex(where: { $0.id == candidate.id }) {
            rules[index] = candidate
        } else {
            rules.append(candidate)
        }
        dataManager.userFilterRules = rules
        return nil
    }

    func delete(at offsets: IndexSet, isProTier: Bool) {
        guard isProTier else { return }
        rules.remove(atOffsets: offsets)
        dataManager.userFilterRules = rules
    }

    /// A short, editable starting phrase for "Add as filter" from the Filter Test result:
    /// whitespace-collapsed, trimmed, and cut at a word boundary.
    nonisolated static func suggestedPattern(from message: String, maxLength: Int = 40) -> String {
        let collapsed = message.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard collapsed.count > maxLength else { return collapsed }
        let prefix = String(collapsed.prefix(maxLength))
        if let lastSpace = prefix.lastIndex(of: " "), prefix.distance(from: prefix.startIndex, to: lastSpace) > maxLength / 2 {
            return String(prefix[..<lastSpace])
        }
        return prefix
    }
}

// MARK: - My Filters screen

struct MyFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreKitService.shared
    @StateObject private var viewModel = MyFiltersViewModel()

    @State private var editorRule: UserFilterRule?
    @State private var showingEditor = false

    var body: some View {
        ZStack {
            (storeService.isProTier ? Color.proNavy : Color.brandNavy)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                    Text("My Filters")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        editorRule = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.brandGold)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!storeService.isProTier || !viewModel.canAddMore)
                    .opacity(storeService.isProTier && viewModel.canAddMore ? 1 : 0.3)
                    .accessibilityLabel("Add filter")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                List {
                    if !storeService.isProTier {
                        Text("Your Pro subscription has ended. Your filters are saved but inactive, and can't be edited until you resubscribe.")
                            .font(.subheadline)
                            .foregroundColor(.brandGold)
                            .listRowBackground(Color.white.opacity(0.1))
                            .accessibilityIdentifier("myFilters.lapsedBanner")
                    }

                    if viewModel.rules.isEmpty {
                        emptyState
                            .listRowBackground(Color.white.opacity(0.1))
                    } else {
                        ForEach(viewModel.rules) { rule in
                            Button {
                                guard storeService.isProTier else { return }
                                editorRule = rule
                                showingEditor = true
                            } label: {
                                ruleRow(rule)
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                            .accessibilityHint(storeService.isProTier ? "Double tap to edit" : "")
                        }
                        .onDelete { offsets in
                            viewModel.delete(at: offsets, isProTier: storeService.isProTier)
                        }
                        .deleteDisabled(!storeService.isProTier)
                    }

                    Text("Your filters stay on this device and are never shared or uploaded. Rules you mark Always Allow win over Block rules, and both win over the built-in filter.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .readableWidth()
            }
        }
        .sheet(isPresented: $showingEditor) {
            UserFilterRuleEditor(viewModel: viewModel, rule: editorRule)
                .modifier(OpaqueSheetBackground(isProTier: storeService.isProTier))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundColor(.brandGold)
            Text("No custom filters yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Block or always allow texts that contain a word or match a pattern. For example, add the keyword \"flash sale\" to send those texts to Junk.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }

    private func ruleRow(_ rule: UserFilterRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rule.pattern)
                .font(rule.kind == .regex ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.white)
                .lineLimit(3)
            HStack(spacing: 8) {
                badge(rule.kind == .regex ? "Regex" : "Keyword", color: .white.opacity(0.6))
                badge(rule.action == .block ? "Block" : "Always Allow",
                      color: rule.action == .block ? .orange : .green)
                if rule.isCaseSensitive { badge("Aa", color: .white.opacity(0.6)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rule.pattern), \(rule.kind == .regex ? "regex" : "keyword"), \(rule.action == .block ? "block" : "always allow")")
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - Add / edit sheet

/// Add/edit sheet with live validation. Reused by "Add as filter" in the Filter Test
/// result via `initialPattern`.
struct UserFilterRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreKitService.shared
    @ObservedObject var viewModel: MyFiltersViewModel

    private let existingRule: UserFilterRule?
    @State private var pattern: String
    @State private var kind: UserFilterRule.Kind
    @State private var action: UserFilterRule.Action
    @State private var isCaseSensitive: Bool
    @State private var saveError: UserFilterRuleError?

    init(viewModel: MyFiltersViewModel, rule: UserFilterRule? = nil, initialPattern: String = "") {
        self.viewModel = viewModel
        self.existingRule = rule
        _pattern = State(initialValue: rule?.pattern ?? initialPattern)
        _kind = State(initialValue: rule?.kind ?? .keyword)
        _action = State(initialValue: rule?.action ?? .block)
        _isCaseSensitive = State(initialValue: rule?.isCaseSensitive ?? false)
    }

    /// Cheap, synchronous checks shown as the user types. The timing guard only runs on Save.
    private var liveError: UserFilterRuleError? {
        if pattern.count > UserFilterRuleValidator.maxPatternLength {
            return .patternTooLong(max: UserFilterRuleValidator.maxPatternLength)
        }
        if kind == .regex, !pattern.isEmpty,
           UserRuleEngine.compile(UserFilterRule(pattern: pattern, kind: .regex, isCaseSensitive: isCaseSensitive)) == nil {
            return .invalidRegex
        }
        return nil
    }

    private var canSave: Bool {
        !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && liveError == nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pattern"), footer: errorFooter) {
                    TextField(kind == .regex ? "Regular expression" : "Word or phrase", text: $pattern)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Pattern")
                    Text("\(pattern.count)/\(UserFilterRuleValidator.maxPatternLength)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section {
                    Picker("Match type", selection: $kind) {
                        Text("Keyword").tag(UserFilterRule.Kind.keyword)
                        Text("Regex").tag(UserFilterRule.Kind.regex)
                    }
                    .pickerStyle(.segmented)
                    Picker("Action", selection: $action) {
                        Text("Block").tag(UserFilterRule.Action.block)
                        Text("Always Allow").tag(UserFilterRule.Action.alwaysAllow)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Case sensitive", isOn: $isCaseSensitive)
                }
            }
            .navigationTitle(existingRule == nil ? "Add Filter" : "Edit Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var errorFooter: some View {
        if let error = saveError ?? liveError {
            Text(error.message).foregroundColor(.red)
        }
    }

    private func save() {
        let rule = UserFilterRule(id: existingRule?.id ?? UUID(), pattern: pattern, kind: kind,
                                  action: action, isCaseSensitive: isCaseSensitive)
        if let error = viewModel.save(rule, isProTier: storeService.isProTier) {
            saveError = error
        } else {
            dismiss()
        }
    }
}
