const weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

function getDateInXMonthsTime(monthShift) {
    const currentDate = new Date();
    return new Date(
        currentDate.getFullYear(),
        currentDate.getMonth() + monthShift,
        monthShift === 0 ? currentDate.getDate() : 1
    );
}

function getCalendarLayout(dateObject, highlightToday) {
    const year = dateObject.getFullYear();
    const month = dateObject.getMonth();
    const firstDay = new Date(year, month, 1);
    const leadingDays = (firstDay.getDay() + 6) % 7;
    const today = new Date();
    const calendar = [];

    for (let week = 0; week < 6; week += 1) {
        const row = [];
        for (let weekday = 0; weekday < 7; weekday += 1) {
            const dayOffset = week * 7 + weekday - leadingDays + 1;
            const cellDate = new Date(year, month, dayOffset);
            const inCurrentMonth = cellDate.getMonth() === month;
            const isToday = highlightToday
                && cellDate.getFullYear() === today.getFullYear()
                && cellDate.getMonth() === today.getMonth()
                && cellDate.getDate() === today.getDate();

            row.push({
                "day": cellDate.getDate(),
                "today": isToday ? 1 : inCurrentMonth ? 0 : -1
            });
        }
        calendar.push(row);
    }

    return calendar;
}
