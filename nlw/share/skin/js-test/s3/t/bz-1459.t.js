var t = new Test.Visual();

t.plan(1);

if (!$.browser.safari) {
    t.skipAll("This test is Safari-specific");
}

t.runAsync([
    t.doCreatePage("NotVeryLongLine"),

    function() { 
        t.is(
            t.$('#contentLeft').css('overflow-y'),
            'hidden',
            "Safari needs overflow-y set to 'hidden' to hide the scrollbar"
        );

        t.endAsync();
    }
]);
