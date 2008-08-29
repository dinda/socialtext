(function($) {

var t = new Test.Visual();

t.plan(5);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?admin_wiki", step2);
}

function step2() {
    t.scrollTo(100);

    t.builder.ok(
        t.$("div#st-display-mode-container").is(":visible"),
        'Display is visible before edit'
    );

    t.builder.ok(
        t.$("div#st-edit-mode-view").is(":hidden") ||
        ( t.$("div#st-edit-mode-view").size() == 0 ),
        'Editor is not visible'
    );

    t.$("div#st-page-content").trigger("dblclick");

    setTimeout(function() {
        t.builder.ok(
            t.iframe.contentWindow.Wikiwyg,
            'Double click starts wikiwyg'
        );
        t.builder.ok(
            t.$("div#st-display-mode-container").is(":hidden"),
            'Display is hidden after doubleclick to edit'
        );

        t.builder.ok(
            t.$("div#st-edit-mode-view").is(":visible"),
            'Editor is now visible'
        );

        t.endAsync();
    }, 1500);
};

})(jQuery);