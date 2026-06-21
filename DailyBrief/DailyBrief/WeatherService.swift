import Foundation

// MARK: - 気象庁 forecast JSON のデコード型
// エンドポイントは2要素配列（[0]=短期/3日, [1]=週間）。本アプリは [0] のみ使用。

struct ForecastResponse: Decodable {
    let publishingOffice: String
    let reportDatetime: String
    let timeSeries: [TimeSeries]
}

struct TimeSeries: Decodable {
    let timeDefines: [String]
    let areas: [AreaForecast]
}

struct AreaForecast: Decodable {
    let area: Area
    let weatherCodes: [String]?
    let weathers: [String]?
    let winds: [String]?
    let waves: [String]?
    let pops: [String]?
    let temps: [String]?
}

struct Area: Decodable {
    let name: String
    let code: String
}

// MARK: - View / Summarizer に渡す整形前の数値ダイジェスト
// 数値は全てここで API 値を保持し、LLM はこれを文章化するだけ。

struct WeatherDigest {
    let area: String          // 一次細分区名（例: 西部）
    let reportDatetime: String
    let todayWeather: String   // 今日の天気
    let pop: String?           // 代表的な降水確率(%)
    let minTemp: String?       // 最低気温(℃)
    let maxTemp: String?       // 最高気温(℃)
}

enum WeatherError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case emptyForecast

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "気象庁からの応答が不正です"
        case .httpError(let code): return "HTTPエラー: \(code)"
        case .emptyForecast: return "予報データが空です"
        }
    }
}

actor WeatherService {
    private let baseURL = "https://www.jma.go.jp/bosai/forecast/data/forecast"

    func fetchForecast(areaCode: String = Config.weatherAreaCode) async throws -> WeatherDigest {
        guard let url = URL(string: "\(baseURL)/\(areaCode).json") else {
            throw WeatherError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw WeatherError.httpError(http.statusCode)
        }
        let responses = try JSONDecoder().decode([ForecastResponse].self, from: data)
        guard let short = responses.first else { throw WeatherError.emptyForecast }
        return Self.digest(from: short)
    }

    /// 短期予報の先頭地点（西部）から今日分を抜き出す。
    /// timeSeries は [0]=天気, [1]=降水確率, [2]=気温 の並び。
    private static func digest(from response: ForecastResponse) -> WeatherDigest {
        let weatherTS = response.timeSeries.first
        let weatherArea = weatherTS?.areas.first

        let popTS = response.timeSeries.count > 1 ? response.timeSeries[1] : nil
        let pop = popTS?.areas.first?.pops?.first

        let tempTS = response.timeSeries.count > 2 ? response.timeSeries[2] : nil
        let temps = tempTS?.areas.first?.temps

        return WeatherDigest(
            area: weatherArea?.area.name ?? "—",
            reportDatetime: response.reportDatetime,
            todayWeather: weatherArea?.weathers?.first ?? "—",
            pop: pop,
            minTemp: temps?.first,
            maxTemp: temps?.last
        )
    }
}
