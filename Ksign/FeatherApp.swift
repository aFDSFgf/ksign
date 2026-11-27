//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import OSLog
import IDeviceSwift

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	let heartbeat = HeartbeatManager.shared
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var accentColorManager = AccentColorManager.shared
    @StateObject var extractManager = ExtractManager.shared
	@StateObject var logsManager = LogsManager.shared
	let storage = Storage.shared

	init() { let appearance = UITabBarAppearance(); appearance.configureWithTransparentBackground(); appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark); appearance.backgroundColor = UIColor.black.withAlphaComponent(0.7); UITabBar.appearance().standardAppearance = appearance; UITabBar.appearance().scrollEdgeAppearance = appearance }; var body: some Scene {
		WindowGroup {
			VStack {
                ExtractHeaderView(extractManager: extractManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
				DownloadHeaderView(downloadManager: downloadManager)
					.transition(.move(edge: .top).combined(with: .opacity))
				SignerRootView()
					.environment(\.managedObjectContext, storage.context)
					.onOpenURL(perform: _handleURL)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
			.animation(.smooth, value: downloadManager.manualDownloads.description)
            .animation(.smooth, value: extractManager.extractItems.description)
			.onReceive(accentColorManager.objectWillChange) { _ in
				accentColorManager.updateGlobalTintColor()
			}
			.onAppear {
				accentColorManager.updateGlobalTintColor()
				if logsManager.isCapturing { logsManager.startCapture() }
			}
		}
	}
	
	private func _handleURL(_ url: URL) {
		if url.scheme == "ksign" {
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				_ = DownloadManager.shared.startDownload(from: downloadURL, id: "FeatherManualDownload_\(UUID().uuidString)")
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { _ in }
				} else {
					FR.handlePackageFile(url) { _ in }
				}
				
				return
			}
			
            if url.pathExtension == "ksign" {
                UIAlertController.showAlertWithOk(title: .localized("Error"), message: .localized("Ksign certificate file (.ksign) is now unsupported from v1.5.1, please refer to use .p12 and .mobileprovision instead."))
            }
		}
	}
	
}

import NimbleViews; struct SignerRootView: View { @State private var showingCertificateImport = false; @State private var showingFilePicker = false; @State private var selectedApp: Imported?; @State private var fileName = "Choose an IPA"; @State private var selectedCertificate = 0; @State private var busy = false; @State private var status = ""; @ObservedObject private var logs = LogsManager.shared; @FetchRequest(entity: Imported.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]) private var importedApps: FetchedResults<Imported>; @FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]) private var certificates: FetchedResults<CertificatePair>; private var currentCertificate: CertificatePair? { certificates.indices.contains(selectedCertificate) ? certificates[selectedCertificate] : nil }; private func profileName(_ cert: CertificatePair) -> String { Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? cert.nickname ?? "Unknown profile" }; private func certificateName(_ cert: CertificatePair) -> String { cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? "Unknown certificate" }; private var header: some View { HStack { Image(systemName: "chevron.left").foregroundStyle(.secondary); Spacer(); Image(systemName: "lock.fill").foregroundStyle(.yellow); Text("iOS Signer").font(.headline); Spacer(); Image(systemName: "chevron.left").hidden() }.padding() }; private var inputSection: some View { VStack(alignment: .leading, spacing: 6) { Text("Input File").foregroundStyle(.secondary); HStack { Text(fileName).lineLimit(1); Spacer(); Button("...") { showingFilePicker = true }.disabled(busy) }.padding(12).background(Color.black.opacity(0.65)).cornerRadius(8); Button("Sign") { sign() }.frame(maxWidth: .infinity).padding(10).background(Color.gray.opacity(0.35)).cornerRadius(8).disabled(busy || selectedApp == nil || currentCertificate == nil) } }; private var profileSection: some View { VStack(alignment: .leading, spacing: 6) { Text("Provisioning Profile").foregroundStyle(.secondary); HStack { Menu { ForEach(Array(certificates.enumerated()), id: \.element.objectID) { index, cert in Button(profileName(cert)) { selectedCertificate = index } } } label: { HStack { Text(currentCertificate.map(profileName) ?? "Select a profile").lineLimit(1); Spacer(); Image(systemName: "chevron.down") } }; Button { showingCertificateImport = true } label: { Image(systemName: "plus") }.padding(.leading, 8) }.padding(12).background(Color.black.opacity(0.65)).cornerRadius(8) } }; private var certificateSection: some View { VStack(alignment: .leading, spacing: 6) { Text("Certificate").foregroundStyle(.secondary); HStack { Menu { ForEach(Array(certificates.enumerated()), id: \.element.objectID) { index, cert in Button(certificateName(cert)) { selectedCertificate = index } } } label: { HStack { Text(currentCertificate.map(certificateName) ?? "Select a certificate").lineLimit(1); Spacer(); Image(systemName: "chevron.down") } }; Button { certificates.forEach { Storage.shared.context.refresh($0, mergeChanges: true) } } label: { Image(systemName: "arrow.clockwise") }.padding(.leading, 8) }.padding(12).background(Color.black.opacity(0.65)).cornerRadius(8) } }; private var logSection: some View { VStack(alignment: .leading, spacing: 6) { Text("Status Log").font(.caption).foregroundStyle(.secondary); ScrollView { LazyVStack(alignment: .leading, spacing: 3) { if !status.isEmpty { Text(status).font(.system(.caption2, design: .monospaced)) }; ForEach(logs.entries) { entry in Text(entry.message).font(.system(.caption2, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) } } }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }.padding().background(Color.black.opacity(0.65)) }; var body: some View { ZStack { KsignBackground().ignoresSafeArea(); VStack(spacing: 0) { header; VStack(alignment: .leading, spacing: 18) { inputSection; profileSection; certificateSection }.padding(.horizontal); Spacer(minLength: 24); logSection.frame(minHeight: 120, maxHeight: 220) } }.preferredColorScheme(.dark).sheet(isPresented: $showingCertificateImport) { CertificatesAddView() }.sheet(isPresented: $showingFilePicker) { FileImporterRepresentableView(allowedContentTypes: [.ipa, .tipa], onDocumentsPicked: { urls in guard let url = urls.first else { return }; let previous = Set(importedApps.map { $0.objectID }); let scoped = url.startAccessingSecurityScopedResource(); selectedApp = nil; fileName = url.lastPathComponent; busy = true; status = "Importing file..."; FR.handlePackageFile(url) { error in if scoped { url.stopAccessingSecurityScopedResource() }; if let error { busy = false; status = error.localizedDescription; return }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selectedApp = importedApps.first { !previous.contains($0.objectID) }; busy = false; status = selectedApp == nil ? "Import completed, but the imported app could not be selected." : "File imported." } } }) }.onAppear { logs.startCapture() } }; private func sign() { guard let app = selectedApp, let cert = currentCertificate, !busy else { return }; busy = true; status = "Signing..."; FR.signPackageFile(app, using: OptionsManager.shared.options, icon: nil, certificate: cert) { error in busy = false; status = error?.localizedDescription ?? "Signing complete." } } }; class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        _createPipeline()
        _createSourcesDirectory()
        if !UserDefaults.standard.bool(forKey: "hasInitializedBuiltInSources") {
            _initializeBuiltInSources()
            UserDefaults.standard.set(true, forKey: "hasInitializedBuiltInSources")
        }
        
        _clean()
        
        _copyServerCertificates()
        _addDefaultCertificates()

#if SERVER
        // fallback just in case xd
        _downloadSSLCertificates()
#endif
        return true
    }
    
    private func _initializeBuiltInSources() { 
        Storage.shared.addBuiltInSources()
    }
    
    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = {
                let config = URLSessionConfiguration.default
                config.urlCache = nil
                return DataLoader(configuration: config)
            }()
            let dataCache = try? DataCache(name: "thewonderofyou.Feather.datacache") // disk cache
            let imageCache = Nuke.ImageCache() // memory cache
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataLoader = dataLoader
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }
        
        ImagePipeline.shared = pipeline
    }
    
    private func _createSourcesDirectory() {
        let fileManager = FileManager.default
        
        let appDirectory = URL.documentsDirectory.appendingPathComponent("App")
        try? fileManager.createDirectoryIfNeeded(at: appDirectory)
        
        let directories = ["Signed", "Unsigned", "Archives", "Server", "Tweaks"].map {
            appDirectory.appendingPathComponent($0)
        }
        
        for url in directories {
            try? fileManager.createDirectoryIfNeeded(at: url)
        }
    }
    
    private func _clean() {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        
        if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory.path()) {
            for file in files {
                try? fileManager.removeItem(atPath: tmpDirectory.appendingPathComponent(file).path())
            }
        }
    }
    
    private func _copyServerCertificates() {
        let fileManager = FileManager.default
        let serverDirectory = URL.documentsDirectory.appendingPathComponent("App/Server")
        
        try? fileManager.createDirectoryIfNeeded(at: serverDirectory)
        
        let filesToCopy = ["server.crt", "server.pem", "commonName.txt"]
        
        for fileName in filesToCopy {
            guard let bundleURL = Bundle.main.url(forResource: fileName.components(separatedBy: ".").first!, withExtension: fileName.components(separatedBy: ".").last!) else {
                print("File \(fileName) not found in app bundle")
                continue
            }
            
            let destinationURL = serverDirectory.appendingPathComponent(fileName)
            
            try? fileManager.removeItem(at: destinationURL)
            
            do {
                try fileManager.copyItem(at: bundleURL, to: destinationURL)
            } catch {
                print("Error copying \(fileName): \(error)")
            }
        }
    }
    
    private func _addDefaultCertificates() {
            guard
                UserDefaults.standard.bool(forKey: "feather.didImportDefaultCertificates") == false,
                let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
            else {
                return
            }
            
            do {
                let folderContents = try FileManager.default.contentsOfDirectory(
                    at: signingAssetsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for folderURL in folderContents {
                    guard folderURL.hasDirectoryPath else { continue }
                    
                    let certName = folderURL.lastPathComponent
                    
                    let p12Url = folderURL.appendingPathComponent("cert.p12")
                    let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
                    let passwordUrl = folderURL.appendingPathComponent("cert.txt")
                    
                    guard
                        FileManager.default.fileExists(atPath: p12Url.path),
                        FileManager.default.fileExists(atPath: provisionUrl.path),
                        FileManager.default.fileExists(atPath: passwordUrl.path)
                    else {
                        Logger.misc.warning("Skipping \(certName): missing required files")
                        continue
                    }
                    
                    let password = try String(contentsOf: passwordUrl, encoding: .utf8)
                    
                    FR.handleCertificateFiles(
                        p12URL: p12Url,
                        provisionURL: provisionUrl,
                        p12Password: password,
                        certificateName: certName,
                    ) { _ in
                        
                    }
                }
                UserDefaults.standard.set(true, forKey: "feather.didImportDefaultCertificates")
            } catch {
                Logger.misc.error("Failed to list signing-assets: \(error)")
            }
        }

#if SERVER
    private func _downloadSSLCertificates() {
        let serverURL = "https://backloop.dev/pack.json"
        
        FR.downloadSSLCertificates(from: serverURL) { success in
            if success {
                print("SSL certificates downloaded successfully")
            } else {
                print("Failed to download SSL certificates")
            }
        }
    }
#endif
}
