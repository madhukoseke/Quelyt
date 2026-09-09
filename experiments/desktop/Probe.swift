import AppKit
final class Probe: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
 var window: NSWindow!
 let count=100000
 func applicationDidFinishLaunching(_ n:Notification) {
  window=NSWindow(contentRect:NSRect(x:0,y:0,width:1050,height:720),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
  window.title="Quelyt · Native interaction probe"
  let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18;stack.edgeInsets=NSEdgeInsets(top:24,left:24,bottom:24,right:24)
  let title=NSTextField(labelWithString:"Explore your data. Locally.");title.font = .systemFont(ofSize:26,weight:.semibold)
  let note=NSTextField(labelWithString:"PROTOTYPE   •   100,000 synthetic rows   •   AppKit virtualized table")
  let editor=NSTextView(frame:NSRect(x:0,y:0,width:950,height:100));editor.string="SELECT region, SUM(amount) AS revenue\nFROM dataset GROUP BY region;";editor.font = .monospacedSystemFont(ofSize:15,weight:.regular);editor.isAutomaticQuoteSubstitutionEnabled=false
  let editorScroll=NSScrollView();editorScroll.documentView=editor;editorScroll.hasVerticalScroller=true
  let table=NSTableView();table.rowHeight=25;table.usesAlternatingRowBackgroundColors=true;table.delegate=self;table.dataSource=self
  for (key,name) in [("id","ID"),("region","Region"),("amount","Amount")]{let col=NSTableColumn(identifier:NSUserInterfaceItemIdentifier(key));col.title=name;col.width=280;table.addTableColumn(col)}
  let scroll=NSScrollView();scroll.documentView=table;scroll.hasVerticalScroller=true
  for v in [title,note,editorScroll,scroll]{stack.addArrangedSubview(v)}
  editorScroll.heightAnchor.constraint(equalToConstant:110).isActive=true
  for v in [editorScroll,scroll]{v.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-48).isActive=true}
  window.contentView=stack;window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
  print("READY rows=100000");fflush(stdout)
 }
 func numberOfRows(in tableView:NSTableView)->Int{count}
 func tableView(_ t:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView?{
  let value=column?.identifier.rawValue == "id" ? String(row) : column?.identifier.rawValue == "region" ? (row%3==0 ? "West":"East") : String(row%100)
  return NSTextField(labelWithString:value)
 }
}
let app=NSApplication.shared;let delegate=Probe();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
