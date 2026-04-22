import Foundation

struct DailyWeather: Equatable {
    let highC: Double
    let lowC: Double
    let weatherCode: Int
    let fetchedAt: Date
    let day: Date
}

@MainActor
final class WeatherService {
    private let http: HTTPClient
    // Suffield Academy, Suffield CT.
    private let latitude = 41.97
    private let longitude = -72.65
    private let cacheTTL: TimeInterval = 60 * 60

    private var cache: DailyWeather?

    init(http: HTTPClient) {
        self.http = http
    }

    /// Returns today's high/low. Cached 1 hour.
    func today(forceRefresh: Bool = false) async -> DailyWeather? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if !forceRefresh, let cached = cache,
           cal.isDate(cached.day, inSameDayAs: today),
           Date.now.timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached
        }
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=temperature_2m_max,temperature_2m_min,weather_code&temperature_unit=celsius&timezone=auto&forecast_days=1"
        guard let url = URL(string: urlString) else { return cache }
        do {
            let data = try await http.data(for: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            guard let high = decoded.daily.temperature_2m_max.first,
                  let low = decoded.daily.temperature_2m_min.first else {
                return cache
            }
            let code = decoded.daily.weather_code.first ?? 0
            let result = DailyWeather(highC: high, lowC: low, weatherCode: code, fetchedAt: .now, day: today)
            cache = result
            return result
        } catch {
            return cache
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weather_code: [Int]
    }
    let daily: Daily
}

extension DailyWeather {
    /// Short symbol name based on WMO weather code for SF Symbols rendering.
    var symbolName: String {
        switch weatherCode {
        case 0: return "sun.max"
        case 1, 2: return "cloud.sun"
        case 3: return "cloud"
        case 45, 48: return "cloud.fog"
        case 51, 53, 55, 56, 57: return "cloud.drizzle"
        case 61, 63, 65, 66, 67: return "cloud.rain"
        case 71, 73, 75, 77: return "cloud.snow"
        case 80, 81, 82: return "cloud.heavyrain"
        case 85, 86: return "cloud.sleet"
        case 95, 96, 99: return "cloud.bolt.rain"
        default: return "thermometer"
        }
    }
}
