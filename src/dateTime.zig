const std = @import("std");

pub const DateTime = @This();

year: u16 = 0,
/// Month of year, starting at January = 1
month: u4 = 0,
/// Day of month
day: u5 = 0,
/// Day of week:
/// Mon = 0, Tue= 1, Wed = 2, Thu = 3, Fri = 4, Sat = 5, Sun = 6
weekday: u3 = 0,
/// Hour of day
hour: u5 = 0,
/// Minute of hour
minute: u6 = 0,
/// Second of minute
second: u6 = 0,

fn getWeekday(days: *const std.time.epoch.EpochDay) u3 {
    const wday64: u64 = (3 + @as(u64, days.day)) % 7;
    std.debug.assert(wday64 <= 6);
    return @intCast(wday64);
}

const weekday_names3 = "MonTueWedThuFriSatSun";
/// 3 letter weekday name in english
pub fn weekdayName3(self: *const DateTime) []const u8 {
    const wday: usize = self.weekday;
    return weekday_names3[wday * 3 .. (wday + 1) * 3];
}

const month_names3 = "JanFebMarAprMayJunJulAugSepOctNovDec";
/// 3 letter month name in english
pub fn monthName3(self: *const DateTime) []const u8 {
    const mon: usize = self.month - 1;
    return weekday_names3[mon * 3 .. (mon + 1) * 3];
}
pub fn nowEpochSeconds() std.time.epoch.EpochSeconds {
    const timestamp_ns: i128 = std.time.nanoTimestamp();
    const timestamp_s: i128 = @divFloor(timestamp_ns, std.time.ns_per_s);
    return std.time.epoch.EpochSeconds{ .secs = @truncate(@abs(timestamp_s)) };
}
pub fn now() DateTime {
    var result: DateTime = .{};

    // const timestamp_ns: u64 = @intCast(std.time.nanoTimestamp());
    // const epoc_seconds = std.time.epoch.EpochSeconds{ .secs = @divFloor(timestamp_ns, std.time.ns_per_s) };
    const epoc_seconds = nowEpochSeconds();
    const epoc_days = epoc_seconds.getEpochDay(); // number of days since the epoch
    const epoc_daySeconds = epoc_seconds.getDaySeconds();
    const epoc_yearAndDay = epoc_days.calculateYearDay();
    const epoc_monthAndDay = epoc_yearAndDay.calculateMonthDay();

    result.year = epoc_yearAndDay.year;
    result.month = epoc_monthAndDay.month.numeric();
    result.day = epoc_monthAndDay.day_index;
    result.weekday = getWeekday(&epoc_days);
    result.hour = epoc_daySeconds.getHoursIntoDay();
    result.minute = epoc_daySeconds.getMinutesIntoHour();
    result.second = epoc_daySeconds.getSecondsIntoMinute();

    return result;
}
