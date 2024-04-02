import WidgetKit
import SwiftUI
import FudanKit

struct WalletWidgetProvier: TimelineProvider {
    func placeholder(in context: Context) -> WalletEntry {
        WalletEntry()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WalletEntry) -> Void) {
        var entry = WalletEntry()
        if !context.isPreview {
            entry.placeholder = true
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            do {
                let balance = try await WalletAPI.getBalance()
                let transactions = try await WalletAPI.getTransactions(page: 1)
                let entry = WalletEntry(balance, transactions)
                let date = Calendar.current.date(byAdding: .hour, value: 1, to: Date.now)!
                let timeline = Timeline(entries: [entry], policy: .after(date))
                completion(timeline)
            } catch {
                var entry = WalletEntry()
                entry.loadFailed = true
                let date = Calendar.current.date(byAdding: .hour, value: 1, to: Date.now)!
                let timeline = Timeline(entries: [entry], policy: .after(date))
                completion(timeline)
            }
        }
    }
}

struct WalletEntry: TimelineEntry {
    let date: Date
    let balance: String
    let transactions: [FudanKit.Transaction]
    var placeholder = false
    var loadFailed = false
    
    init() {
        date = Date()
        balance = "100.0"
        transactions = []
    }
    
    init(_ balance: String, _ transactions: [FudanKit.Transaction]) {
        date = Date()
        self.balance = balance
        self.transactions = transactions
    }
}

public struct WalletWidget: Widget {
    public init() { }
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ecard.fudan.edu.cn", provider: WalletWidgetProvier()) { entry in
            WalletWidgetView(entry: entry)
        }
        .configurationDisplayName("ECard")
        .description("Check ECard balance and transactions.")
        .supportedFamilies([.systemSmall])
    }
}

struct WalletWidgetView: View {
    let entry: WalletEntry
    
    var body: some View {
        if #available(iOS 17, *) {
            widgetContent
                .containerBackground(.fill, for: .widget)
        } else {
            widgetContent
                .padding()
        }
    }
    
    @ViewBuilder
    private var widgetContent: some View {
        if entry.loadFailed {
            Text("Load Failed")
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("ECard", systemImage: "creditcard.fill")
                        .bold()
                        .font(.callout)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                if entry.placeholder {
                    walletContent.redacted(reason: .placeholder)
                } else {
                    walletContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var walletContent: some View {
        Text("¥\(entry.balance)")
            .bold()
            .font(.title2)
            .foregroundColor(.primary.opacity(0.7))

        Spacer()
        
        if let transaction = entry.transactions.first {
            Label("\(transaction.location) \(transaction.amount)", systemImage: "clock")
                .bold()
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}

#Preview {
    WalletWidgetView(entry: .init())
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}
