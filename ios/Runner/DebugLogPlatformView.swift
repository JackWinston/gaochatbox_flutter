import UIKit
import Flutter

/// 调试日志原生视图 — iOS 侧实现。
///
/// 使用 UITableView 渲染日志列表，
/// 通过 MethodChannel 与 Flutter 侧通信（长按复制、下拉刷新）。
class DebugLogNativeView: NSObject, FlutterPlatformView {

    private let tableView: UITableView
    private let channel: FlutterMethodChannel
    private var entries: [LogEntry] = []
    private var themeColors: ThemeColors

    struct LogEntry {
        let type: String
        let timestamp: String
        let url: String
        let requestBody: String
        let responseBody: String
        let isError: Bool
    }

    struct ThemeColors {
        let surface: UIColor
        let surfaceContainerLow: UIColor
        let onSurface: UIColor
        let onSurfaceVariant: UIColor
        let primary: UIColor
        let error: UIColor
        let errorContainer: UIColor
        let onErrorContainer: UIColor
        let outlineVariant: UIColor
    }

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: [String: Any]?,
        channel: FlutterMethodChannel
    ) {
        self.channel = channel
        self.themeColors = ThemeColors(
            surface: .systemBackground,
            surfaceContainerLow: .secondarySystemBackground,
            onSurface: .label,
            onSurfaceVariant: .secondaryLabel,
            primary: .systemPurple,
            error: .systemRed,
            errorContainer: UIColor.systemRed.withAlphaComponent(0.15),
            onErrorContainer: .systemRed,
            outlineVariant: .separator
        )

        tableView = UITableView(frame: frame, style: .plain)
        tableView.separatorStyle = .none
        tableView.backgroundColor = themeColors.surfaceContainerLow

        super.init()

        // 解析主题颜色
        if let colors = args?["colors"] as? [String: Any] {
            themeColors = ThemeColors(
                surface: colorFromInt(colors["surface"]) ?? .systemBackground,
                surfaceContainerLow: colorFromInt(colors["surfaceContainerLow"]) ?? .secondarySystemBackground,
                onSurface: colorFromInt(colors["onSurface"]) ?? .label,
                onSurfaceVariant: colorFromInt(colors["onSurfaceVariant"]) ?? .secondaryLabel,
                primary: colorFromInt(colors["primary"]) ?? .systemPurple,
                error: colorFromInt(colors["error"]) ?? .systemRed,
                errorContainer: colorFromInt(colors["errorContainer"]) ?? UIColor.systemRed.withAlphaComponent(0.15),
                onErrorContainer: colorFromInt(colors["onErrorContainer"]) ?? .systemRed,
                outlineVariant: colorFromInt(colors["outlineVariant"]) ?? .separator
            )
        }

        // 解析日志条目
        if let rawEntries = args?["entries"] as? [[String: Any]] {
            entries = rawEntries.map { dict in
                LogEntry(
                    type: dict["type"] as? String ?? "",
                    timestamp: dict["timestamp"] as? String ?? "",
                    url: dict["url"] as? String ?? "",
                    requestBody: dict["requestBody"] as? String ?? "",
                    responseBody: dict["responseBody"] as? String ?? "",
                    isError: dict["isError"] as? Bool ?? false
                )
            }
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntryCell")
        tableView.reloadData()
    }

    func view() -> UIView {
        return tableView
    }

    private func colorFromInt(_ value: Any?) -> UIColor? {
        guard let intVal = value as? Int else { return nil }
        let a = CGFloat((intVal >> 24) & 0xFF) / 255.0
        let r = CGFloat((intVal >> 16) & 0xFF) / 255.0
        let g = CGFloat((intVal >> 8) & 0xFF) / 255.0
        let b = CGFloat(intVal & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension DebugLogNativeView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogEntryCell", for: indexPath) as! LogEntryCell
        let entry = entries[indexPath.row]
        cell.configure(with: entry, colors: themeColors)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }

    // 长按菜单
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copyAction = UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                self?.channel.invokeMethod("onCopyEntry", arguments: indexPath.row)
            }
            return UIMenu(title: "", children: [copyAction])
        }
    }
}

// MARK: - LogEntryCell

class LogEntryCell: UITableViewCell {

    private let cardView = UIView()
    private let typeLabel = UILabel()
    private let timestampLabel = UILabel()
    private let errorBadge = UILabel()
    private let urlTitleLabel = UILabel()
    private let urlContentLabel = UILabel()
    private let requestTitleLabel = UILabel()
    private let requestContentLabel = UILabel()
    private let responseTitleLabel = UILabel()
    private let responseContentLabel = UILabel()

    private var requestTitleTopConstraint: NSLayoutConstraint?
    private var requestContentTopConstraint: NSLayoutConstraint?
    private var responseTitleTopConstraint: NSLayoutConstraint?
    private var responseContentTopConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Card
        cardView.layer.cornerRadius = 18
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
        ])

        // Header row
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 8

        let headerTexts = UIStackView()
        headerTexts.axis = .vertical
        headerTexts.spacing = 4

        typeLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headerTexts.addArrangedSubview(typeLabel)

        timestampLabel.font = .systemFont(ofSize: 12)
        headerTexts.addArrangedSubview(timestampLabel)

        headerRow.addArrangedSubview(headerTexts)

        errorBadge.font = .systemFont(ofSize: 12)
        errorBadge.textAlignment = .center
        errorBadge.layer.cornerRadius = 999
        errorBadge.clipsToBounds = true
        errorBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            errorBadge.heightAnchor.constraint(equalToConstant: 22),
        ])
        headerRow.addArrangedSubview(errorBadge)

        stackView.addArrangedSubview(headerRow)

        // URL section
        urlTitleLabel.text = "URL"
        urlTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        let urlTitleSpacer = makeSpacer(height: 10)
        stackView.addArrangedSubview(urlTitleSpacer)
        stackView.addArrangedSubview(urlTitleLabel)

        urlContentLabel.font = .systemFont(ofSize: 14)
        urlContentLabel.numberOfLines = 0
        let urlContentSpacer = makeSpacer(height: 6)
        stackView.addArrangedSubview(urlContentSpacer)
        stackView.addArrangedSubview(urlContentLabel)

        // Request section
        requestTitleLabel.text = "Request"
        requestTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        requestTitleLabel.isHidden = true
        requestTitleTopConstraint = requestTitleLabel.topAnchor.constraint(equalTo: urlContentLabel.bottomAnchor, constant: 12)
        stackView.addArrangedSubview(requestTitleLabel)

        requestContentLabel.font = .systemFont(ofSize: 14)
        requestContentLabel.numberOfLines = 0
        requestContentLabel.isHidden = true
        stackView.addArrangedSubview(requestContentLabel)

        // Response section
        responseTitleLabel.text = "Response"
        responseTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        responseTitleLabel.isHidden = true
        stackView.addArrangedSubview(responseTitleLabel)

        responseContentLabel.font = .systemFont(ofSize: 14)
        responseContentLabel.numberOfLines = 0
        responseContentLabel.isHidden = true
        stackView.addArrangedSubview(responseContentLabel)
    }

    private func makeSpacer(height: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    func configure(with entry: LogEntry, colors: DebugLogNativeView.ThemeColors) {
        cardView.backgroundColor = colors.surfaceContainerLow
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = colors.outlineVariant.cgColor

        typeLabel.text = entry.type
        typeLabel.textColor = colors.onSurface

        timestampLabel.text = entry.timestamp
        timestampLabel.textColor = colors.onSurfaceVariant

        if entry.isError {
            errorBadge.isHidden = false
            errorBadge.text = " Error "
            errorBadge.backgroundColor = colors.errorContainer
            errorBadge.textColor = colors.onErrorContainer
        } else {
            errorBadge.isHidden = true
        }

        urlTitleLabel.textColor = colors.primary
        urlContentLabel.text = entry.url
        urlContentLabel.textColor = colors.onSurface

        if !entry.requestBody.isEmpty {
            requestTitleLabel.isHidden = false
            requestTitleLabel.textColor = colors.primary
            requestContentLabel.isHidden = false
            requestContentLabel.text = entry.requestBody
            requestContentLabel.textColor = colors.onSurface
        } else {
            requestTitleLabel.isHidden = true
            requestContentLabel.isHidden = true
        }

        if !entry.responseBody.isEmpty {
            responseTitleLabel.isHidden = false
            responseTitleLabel.textColor = colors.primary
            responseContentLabel.isHidden = false
            responseContentLabel.text = entry.responseBody
            responseContentLabel.textColor = colors.onSurface
        } else {
            responseTitleLabel.isHidden = true
            responseContentLabel.isHidden = true
        }
    }
}

// MARK: - FlutterPlatformViewFactory

class DebugLogViewFactory: NSObject, FlutterPlatformViewFactory {

    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let dict = args as? [String: Any]
        return DebugLogNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: dict,
            channel: channel
        )
    }
}
