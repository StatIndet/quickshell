import QtQuick
import QtTest
import "../../Common/functions/SpotlightSearch.js" as SpotlightSearch

TestCase {
    function test_emptyQuery() {
        compare(SpotlightSearch.searchUrl("google", " \n\t "), "");
    }

    function test_queryEncoding() {
        compare(SpotlightSearch.searchUrl("bing", "  中文 & a+b?#  "), "https://www.bing.com/search?q=%E4%B8%AD%E6%96%87%20%26%20a%2Bb%3F%23");
        compare(SpotlightSearch.searchUrl("yahoo", "a=b"), "https://search.yahoo.com/search?p=a%3Db");
    }

    function test_preferenceFallback() {
        compare(SpotlightSearch.normalizedEngine(undefined), "google");
        compare(SpotlightSearch.normalizedEngine("removed-provider"), "google");
        compare(SpotlightSearch.normalizedEngine("duckduckgo"), "duckduckgo");
        compare(SpotlightSearch.searchUrl("removed-provider", "hello"), "https://www.google.com/search?q=hello");
    }

    name: "SpotlightSearch"
}
