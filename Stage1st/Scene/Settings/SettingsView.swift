//
//  SettingsView.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import SwiftUI
import Combine
import Kingfisher

class SettingsViewState: ObservableObject {

    typealias ObjectWillChangePublisher = ObservableObjectPublisher

    private var bag = Set<AnyCancellable>()

    private let currentUsernameSubject: CurrentValueSubject<String?, Never>
    var currentLoggedInUsername: String? {
        get { currentUsernameSubject.value }
        set {
            if currentUsernameSubject.value != newValue {
                objectWillChange.send()
                currentUsernameSubject.send(newValue)
            }
        }
    }

    let showLoginViewController: () -> Void

    init(
        currentUsernameSubject: CurrentValueSubject<String?, Never>,
        showLoginViewController: @escaping () -> Void
    ) {
        self.currentUsernameSubject = currentUsernameSubject
        self.showLoginViewController = showLoginViewController

        currentUsernameSubject
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.currentLoggedInUsername = newValue
            }
            .store(in: &bag)
    }
}

struct SettingsView: View {

    @ObservedObject var state: SettingsViewState

    @AppStorage("showImageOnMobileNetwork") var showImageOnMobileNetwork: Bool = true
    @AppStorage("removeTails") var removeTails: Bool = true
    @AppStorage("HistoryLimit") var historyLimitInSeconds: Int = -1
    @AppStorage("FontSize") var fontSize: String = ""
    @AppStorage("Precache") var enablePrecache: Bool = true
    @AppStorage("Portrait") var lockPortrait: Bool = true
    @AppStorage("NightMode") var nightMode: Bool = true
    @AppStorage("NightModeMatchSystem") var nightModeMatchSystem: Bool = true

    enum HistoryLimit: Int {
        case threeDays = 259200
        case oneWeek = 604800
        case twoWeeks = 1209600
        case oneMonth = 2592000
        case threeMonths = 7884000
        case sixMonths = 15768000
        case oneYear = 31536000
        case forever = -1

    }

    var historyLimit: HistoryLimit {
        get { HistoryLimit(rawValue: historyLimitInSeconds) ?? .forever }
        nonmutating set { historyLimitInSeconds = newValue.rawValue }
    }

    var historyLimitBinding: Binding<HistoryLimit> {
        Binding<HistoryLimit>(
            get: { historyLimit },
            set: { newValue, transaction in self.historyLimit = newValue }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                userSection()
                appearanceSection()
                miscSection()
            }
            .navigationTitle("SettingsViewController.NavigationBar_Title")
        }
    }
}

// MARK: - Sections

private extension SettingsView {
    func userSection() -> some View {
        Section {
            if let username = state.currentLoggedInUsername {
                HStack {
                    KFImage(URL(string: ""))
                        .frame(width: 50.0, height: 50.0)
                        .background(Color.gray)
                        .clipShape(Circle())
                    Text(username)
                    Spacer()
                    Button(action: {}) {
                        HStack {
                            Text("SettingsViewController.LogOut")
                        }
                    }
                }
            } else {
                Button(action: {}) {
                    HStack {
                        Text("SettingsViewController.LogIn")
                    }
                }
            }
        }
    }

    func appearanceSection() -> some View {
        Section(header: Text("SettingsViewController.Section.Appearance")) {
            Picker("SettingsViewController.Font_Size", selection: $fontSize) {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Text("15px").tag("15px")
                    Text("17px").tag("17px")
                    Text("19px").tag("19px")
                    Text("21px").tag("21px")
                    Text("23px").tag("23px")
                } else {
                    Text("18px").tag("18px")
                    Text("20px").tag("20px")
                    Text("22px").tag("22px")
                    Text("24px").tag("24px")
                    Text("26px").tag("26px")
                }
            }
            Toggle("SettingsViewController.Display_Image", isOn: $showImageOnMobileNetwork)
            Toggle("SettingsViewController.Remove_Tails", isOn: $showImageOnMobileNetwork)
            Toggle("SettingsViewController.NightMode", isOn: $nightMode)
            Toggle("SettingsViewController.NightModeMatchSystem", isOn: $nightModeMatchSystem)
        }
    }

    func miscSection() -> some View {
        Section {
            Button(action: {}) {
                Text("SettingsViewController.Forum_Order_Custom")
            }
            Picker("SettingsViewController.HistoryLimit", selection: historyLimitBinding) {
                Text("SettingsViewController.HistoryLimit.Forever").tag(HistoryLimit.forever)
                Text("SettingsViewController.HistoryLimit.3days").tag(HistoryLimit.threeDays)
                Text("SettingsViewController.HistoryLimit.1week").tag(HistoryLimit.oneWeek)
                Text("SettingsViewController.HistoryLimit.2weeks").tag(HistoryLimit.twoWeeks)
                Text("SettingsViewController.HistoryLimit.1month").tag(HistoryLimit.oneMonth)
                Text("SettingsViewController.HistoryLimit.3months").tag(HistoryLimit.threeMonths)
                Text("SettingsViewController.HistoryLimit.6months").tag(HistoryLimit.sixMonths)
                Text("SettingsViewController.HistoryLimit.1year").tag(HistoryLimit.oneYear)
            }
            Toggle("SettingsViewController.Precache", isOn: $enablePrecache)
            Toggle("SettingsViewController.LockPortrait", isOn: $lockPortrait)
        }
    }
}

// MARK: - Actions

private extension SettingsView {

    func login() {
        state.showLoginViewController()
    }

    func logout() {
        AppEnvironment.current.apiService.logOut()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(state: SettingsViewState(
            currentUsernameSubject: CurrentValueSubject("ainopara"),
            showLoginViewController: { }
        ))
    }
}
