// Shared catalog for preference validation, settings and URL construction.
var engines = [
    {
        "id": "google",
        "icon": "google.ico",
        "label": "Google",
        "url": "https://www.google.com/search?q="
    },
    {
        "id": "bing",
        "icon": "bing.ico",
        "label": "Bing",
        "url": "https://www.bing.com/search?q="
    },
    {
        "id": "duckduckgo",
        "icon": "duckduckgo.png",
        "label": "DuckDuckGo",
        "url": "https://duckduckgo.com/?q="
    },
    {
        "id": "yahoo",
        "icon": "yahoo.ico",
        "label": "Yahoo",
        "url": "https://search.yahoo.com/search?p="
    },
    {
        "id": "baidu",
        "icon": "baidu.ico",
        "label": "百度",
        "url": "https://www.baidu.com/s?wd="
    },
    {
        "id": "yandex",
        "icon": "yandex.png",
        "label": "Yandex",
        "url": "https://yandex.com/search/?text="
    },
    {
        "id": "brave",
        "icon": "brave.svg",
        "label": "Brave Search",
        "url": "https://search.brave.com/search?q="
    },
    {
        "id": "startpage",
        "icon": "startpage.png",
        "label": "Startpage",
        "url": "https://www.startpage.com/sp/search?query="
    },
    {
        "id": "ecosia",
        "icon": "ecosia.ico",
        "label": "Ecosia",
        "url": "https://www.ecosia.org/search?q="
    },
    {
        "id": "qwant",
        "icon": "qwant.png",
        "label": "Qwant",
        "url": "https://www.qwant.com/?q="
    },
    {
        "id": "naver",
        "icon": "naver.png",
        "label": "Naver",
        "url": "https://search.naver.com/search.naver?query="
    },
    {
        "id": "yahoo-japan",
        "icon": "yahoo-japan.png",
        "label": "Yahoo! Japan",
        "url": "https://search.yahoo.co.jp/search?p="
    },
    {
        "id": "sogou",
        "icon": "sogou.ico",
        "label": "搜狗",
        "url": "https://www.sogou.com/web?query="
    },
    {
        "id": "360",
        "icon": "360.png",
        "label": "360 搜索",
        "url": "https://www.so.com/s?q="
    },
    {
        "id": "seznam",
        "icon": "seznam.png",
        "label": "Seznam",
        "url": "https://search.seznam.cz/?q="
    },
    {
        "id": "daum",
        "icon": "daum.ico",
        "label": "Daum",
        "url": "https://search.daum.net/search?q="
    },
    {
        "id": "coccoc",
        "icon": "coccoc.png",
        "label": "Cốc Cốc",
        "url": "https://coccoc.com/search?query="
    }
];

function engineFor(value) {
    return engines.find(function(engine) { return engine.id === value; }) || engines[0];
}

function normalizedEngine(value) {
    return engineFor(String(value || "")).id;
}

function searchUrl(engineId, query) {
    var value = String(query || "").trim();
    return value ? engineFor(engineId).url + encodeURIComponent(value) : "";
}
