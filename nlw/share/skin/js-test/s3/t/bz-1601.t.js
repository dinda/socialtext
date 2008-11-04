(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/data/workspaces/admin/pages?q=admin+wiki", t.nextStep());
    },
            
    function() { 
        t.ok(
            t.doc.getElementsByTagName('a').length,
            "REST search with a single hit displayed correctly"
        );
        t.endAsync();
    }
]);

})(jQuery);
