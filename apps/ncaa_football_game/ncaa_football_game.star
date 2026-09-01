# NCAA Football Game
# Separate NCAA Division I counterpart to apps/nfl_game.
# Preserves the NFL Game 64x32 layouts while using ESPN college-football data.

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

WHITE="#ffffff"
BLACK="#000000"
YELLOW="#ffff00"
FALLBACK_BG="#202020"
DIVISION_GROUPS=[80,81]

def spacer_w(w): return render.Box(width=w,height=1)
def spacer_h(h): return render.Box(width=1,height=h)
def s(v,d=""): return v if v!=None and type(v)=="string" else d
def i(v,d=0): return v if v!=None and type(v)=="int" else d

def fetch_json(url,ttl=30):
    r=http.get(url=url,ttl_seconds=ttl)
    if r.status_code!=200: return None
    b=r.body()
    if b==None or len(b)==0 or b[0]!="{": return None
    return json.decode(b)

def score_int(v):
    if type(v)=="int": return v
    if type(v)=="string":
        for n in range(0,100):
            if v==str(n): return n
    return 0

def logo_bytes(url):
    if url=="": return None
    r=http.get(url=url,ttl_seconds=36000)
    return r.body() if r.status_code==200 else None

def logo_url(team):
    logos=team.get("logos")
    if type(logos)=="list":
        for logo in logos:
            if type(logo)!="dict": continue
            href=s(logo.get("href"),"")
            if href.find("-dark/")!=-1: return href
        for logo in logos:
            if type(logo)=="dict" and s(logo.get("href"),"")!="": return s(logo.get("href"),"")
    direct=s(team.get("logo"),"")
    if direct!="": return direct.replace("/500/","/500-dark/")
    return ""

def complete_team(team):
    if type(team)!="dict": return team
    tid=s(team.get("id"),"")
    if tid=="": return team
    data=fetch_json("https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/"+tid,21600)
    full=data.get("team") if type(data)=="dict" else None
    return full if type(full)=="dict" else team

def team_meta(team):
    team=complete_team(team)
    if type(team)!="dict": return {"id":"","code":"NCAA","name":"NCAA","bg":FALLBACK_BG,"logo":""}
    code=s(team.get("abbreviation"),"NCAA")
    col=s(team.get("color"),"")
    if col!="" and col[0]!="#": col="#"+col
    if col=="" or col=="#000000" or col=="#ffffff":
        alt=s(team.get("alternateColor"),"")
        if alt!="" and alt[0]!="#": alt="#"+alt
        col=alt if alt!="" and alt!="#000000" and alt!="#ffffff" else FALLBACK_BG
    return {"id":s(team.get("id"),""),"code":code,"name":s(team.get("displayName"),s(team.get("shortDisplayName"),code)),"bg":col,"logo":logo_url(team)}

def record_text(c):
    if type(c)!="dict": return ""
    records=c.get("records")
    if type(records)!="list": return ""
    for r in records:
        if type(r)=="dict" and s(r.get("summary"),"")!="": return s(r.get("summary"),"")
    return ""

def logo_node(meta,width,height=None):
    if height==None: height=width
    img=logo_bytes(meta["logo"])
    if img!=None: return render.Image(img,width=width,height=height)
    return render.Text(meta["code"][0],font="6x13",color=WHITE)

def shifted_team_text(text,width,height,font):
    return render.Box(width=width,height=height,child=render.Row(children=[spacer_w(1),render.Box(width=width-1,height=height,child=render.Row(children=[render.Text(text,font=font,color=WHITE)],main_align="center",cross_align="center"))],main_align="start",cross_align="center"))

def team_code_row(meta,width,height):
    return render.Box(width=width,height=height,child=render.Column(children=[spacer_h(1),render.Box(width=width,height=height-1,child=render.Row(children=[render.Text(meta["code"],font="tom-thumb",color=WHITE)],main_align="center",cross_align="center"))],main_align="start",cross_align="stretch"))

def pregame_team_column(meta,record,width):
    logo=logo_node(meta,19,18)
    return render.Box(color=meta["bg"],width=width,height=32,child=render.Column(children=[team_code_row(meta,width,6),render.Box(width=width,height=18,child=render.Row(children=[logo],main_align="center",cross_align="center")),shifted_team_text(record,width,8,"CG-pixel-3x5-mono")],main_align="start",cross_align="stretch"))

def game_team_tile(meta,score,possession,live,score_color=WHITE):
    logo_width=17 if live else 20; info_width=15; logo=logo_node(meta,logo_width,16)
    if live:
        possession_box=render.Box(width=2,height=9,child=render.Column(children=[render.Box(width=2,height=2,color=WHITE) if possession else spacer_w(2)],main_align="center",cross_align="center"))
        score_row=render.Box(width=info_width,height=9,child=render.Row(children=[spacer_w(2),render.Box(width=11,height=9,child=render.Row(children=[render.Text(str(score),font="5x8",color=score_color)],main_align="center",cross_align="center")),possession_box],main_align="start",cross_align="center"))
    else:
        score_row=render.Box(width=info_width,height=9,child=render.Row(children=[render.Text(str(score),font="5x8",color=score_color)],main_align="center",cross_align="center"))
    info=render.Box(width=info_width,height=16,child=render.Column(children=[team_code_row(meta,info_width,7),score_row],main_align="start",cross_align="stretch")); lw=17 if live else 20
    return render.Box(color=meta["bg"],width=36,height=16,child=render.Row(children=[render.Box(width=lw,height=16,child=render.Row(children=[logo],main_align="center",cross_align="center")),spacer_w(1),info],main_align="start",cross_align="center"))

def left_panel(g):
    live=g["state"]=="live"; final=g["state"]=="final"; ac=YELLOW if final and g["away_score"]>g["home_score"] else WHITE; hc=YELLOW if final and g["home_score"]>g["away_score"] else WHITE
    return render.Box(width=36,child=render.Column(children=[game_team_tile(g["away"],g["away_score"],g["possession"]==g["away"]["id"],live,ac),game_team_tile(g["home"],g["home_score"],g["possession"]==g["home"]["id"],live,hc)]))

def centered_panel_text(text,height,font,color): return render.Box(width=28,height=height,child=render.Row(children=[render.Text(text,font=font,color=color)],main_align="center",cross_align="center"))
def compact_preview_row(text,width,height,font,color): return render.Box(width=width,height=height,child=render.Row(children=[render.Text(text,font=font,color=color)],main_align="center",cross_align="center"))
def pregame_date_row(month,day,color,width): return render.Box(width=width,height=8,child=render.Row(children=[render.Text(month,font="tom-thumb",color=color),spacer_w(2),render.Text(day,font="tom-thumb",color=color)],main_align="center",cross_align="center"))
def pregame_time_row(hour,minute,color,width):
    colon=render.Box(width=1,height=8,child=render.Column(children=[spacer_h(1),render.Box(width=1,height=1,color=color),spacer_h(2),render.Box(width=1,height=1,color=color),spacer_h(3)]))
    return render.Box(width=width,height=15,child=render.Column(children=[spacer_h(2),render.Box(width=width,height=13,child=render.Row(children=[render.Text(hour,font="5x8",color=color),spacer_w(1),colon,spacer_w(1),render.Text(minute,font="5x8",color=color)],main_align="center",cross_align="center"))]))
def preview_panel(g,config,width=28):
    dc=s(config.get("pregame_date_color"),WHITE); tc=s(config.get("pregame_time_color"),WHITE)
    return render.Box(width=width,height=32,child=render.Column(children=[spacer_h(1),compact_preview_row(g["weekday_text"],width,7,"tom-thumb",dc),pregame_date_row(g["month_text"],g["day_text"],dc,width),pregame_time_row(g["clock_hour"],g["clock_minute"],tc,width),spacer_h(1)]))
def bye_center_panel(): return render.Box(color=BLACK,width=18,height=32,child=render.Column(children=[spacer_h(8),compact_preview_row("BYE",18,9,"5x8",WHITE),spacer_h(1),compact_preview_row("WEEK",18,6,"tom-thumb",WHITE),spacer_h(8)],main_align="start",cross_align="stretch"))
def bye_next_panel(g):
    meta=g["team"]
    return render.Box(color=meta["bg"],width=23,height=32,child=render.Column(children=[spacer_h(2),render.Box(width=23,height=8,child=render.Row(children=[render.Text("NEXT",font="5x8",color=WHITE)],main_align="center",cross_align="center")),render.Box(width=23,height=8,child=render.Row(children=[render.Text("GAME",font="5x8",color=WHITE)],main_align="center",cross_align="center")),spacer_h(3),render.Box(width=23,height=5,child=render.Row(children=[render.Text(g["month_text"],font="CG-pixel-3x5-mono",color=WHITE),spacer_w(3),render.Text(g["day_text"],font="CG-pixel-3x5-mono",color=WHITE)],main_align="center",cross_align="center")),spacer_h(6)],main_align="start",cross_align="stretch"))
def render_bye(g): return render.Box(color=BLACK,width=64,height=32,child=render.Row(children=[pregame_team_column(g["team"],g["record"],23),bye_center_panel(),bye_next_panel(g)],main_align="start",cross_align="start"))
def live_clock_row(clock,color):
    parts=clock.split(":")
    if len(parts)!=2: return centered_panel_text(clock,10,"5x8",color)
    colon=render.Box(width=1,height=8,child=render.Column(children=[spacer_h(2),render.Box(width=1,height=1,color=color),spacer_h(2),render.Box(width=1,height=1,color=color),spacer_h(2)]))
    return render.Box(width=28,height=10,child=render.Row(children=[render.Text(parts[0],font="5x8",color=color),spacer_w(1),colon,spacer_w(1),render.Text(parts[1],font="5x8",color=color)],main_align="center",cross_align="center"))
def live_panel(g,config):
    qc=s(config.get("quarter_color"),WHITE); tc=s(config.get("clock_color"),WHITE)
    if g["halftime"]: return centered_panel_text("HALFTIME",32,"tom-thumb",qc)
    return render.Box(width=28,height=32,child=render.Column(children=[spacer_h(7),centered_panel_text(g["quarter"],6,"tom-thumb",qc),spacer_h(2),live_clock_row(g["clock"],tc),spacer_h(7)],main_align="start",cross_align="stretch"))
def final_panel(config): return centered_panel_text("FINAL",32,"5x8",s(config.get("final_color"),WHITE))
def render_game(g,config):
    if g["state"]=="bye": return render_bye(g)
    if g["state"]=="pre": return render.Box(color=BLACK,width=64,height=32,child=render.Row(children=[pregame_team_column(g["away"],g["away_record"],21),preview_panel(g,config,22),pregame_team_column(g["home"],g["home_record"],21)]))
    return render.Box(color=BLACK,width=64,height=32,child=render.Row(children=[left_panel(g),live_panel(g,config) if g["state"]=="live" else final_panel(config)]))

def parse_competition(event,timezone):
    comps=event.get("competitions") if type(event)=="dict" else None
    if type(comps)!="list" or len(comps)==0: return None
    comp=comps[0]; cs=comp.get("competitors")
    if type(cs)!="list": return None
    away=None; home=None; ascore=0; hscore=0; arec=""; hrec=""
    for c in cs:
        if type(c)!="dict": continue
        meta=team_meta(c.get("team"))
        if s(c.get("homeAway"))=="away": away=meta; ascore=score_int(c.get("score")); arec=record_text(c)
        elif s(c.get("homeAway"))=="home": home=meta; hscore=score_int(c.get("score")); hrec=record_text(c)
    if away==None or home==None: return None
    status=event.get("status"); st=status.get("type") if type(status)=="dict" else {}; raw=s(st.get("state"),"pre") if type(st)=="dict" else "pre"; state="live" if raw=="in" else ("final" if raw=="post" else "pre")
    clock=s(status.get("displayClock"),"") if type(status)=="dict" else ""; period=i(status.get("period"),0) if type(status)=="dict" else 0; quarter="OT" if period>4 else ({1:"1st",2:"2nd",3:"3rd",4:"4th"}.get(period,"")); halftime=state=="live" and period==2 and clock.find("0:00")==0
    situation=comp.get("situation"); possession=s(situation.get("possession"),"") if type(situation)=="dict" else ""
    date_raw=s(event.get("date"),""); et=None; wd="TBD"; mo=""; day=""; hr=""; minute=""
    if date_raw!="":
        p=date_raw
        if len(p)==17 and p[16]=="Z": p=p[:16]+":00Z"
        et=time.parse_time(p).in_location(timezone); wd=et.format("Mon").upper(); mo=et.format("Jan").upper(); day=et.format("2"); hr=et.format("3"); minute=et.format("04")
    season=event.get("season"); season_type=i(season.get("type"),2) if type(season)=="dict" else 2; week=event.get("week"); week_number=i(week.get("number"),0) if type(week)=="dict" else 0
    return {"away":away,"home":home,"away_score":ascore,"home_score":hscore,"away_record":arec,"home_record":hrec,"state":state,"quarter":quarter,"clock":clock,"halftime":halftime,"possession":possession,"event_time":et,"weekday_text":wd,"month_text":mo,"day_text":day,"clock_hour":hr,"clock_minute":minute,"season_type":season_type,"week_number":week_number}

def parse_scoreboard(data,config):
    if type(data)!="dict" or type(data.get("events"))!="list": return []
    out=[]; tz=s(config.get("timezone"),"America/New_York")
    for e in data.get("events"):
        g=parse_competition(e,tz)
        if g!=None: out.append(g)
    return out

def scoreboard(config,group,date_key=""):
    url="https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard?limit=200&groups="+str(group)
    if date_key!="": url=url+"&dates="+date_key
    return parse_scoreboard(fetch_json(url,30),config)
def division_games(config,date_key=""):
    out=[]; seen={}
    for group in DIVISION_GROUPS:
        for g in scoreboard(config,group,date_key):
            key=g["away"]["id"]+"-"+g["home"]["id"]+"-"+(g["event_time"].format("200601021504") if g["event_time"]!=None else "")
            if seen.get(key)!=None: continue
            seen[key]=True; out.append(g)
    return out

def weekly_rollover_start():
    now=time.now().in_location("America/New_York"); wd=now.format("Mon"); back={"Tue":0,"Wed":1,"Thu":2,"Fri":3,"Sat":4,"Sun":5,"Mon":6}.get(wd,0)
    if wd=="Tue" and now.hour<5: back=7
    hours=back*24+(now.hour-5); return now-time.parse_duration(str(hours)+"h"+str(now.minute)+"m"+str(now.second)+"s")
def games_in_cycle(config):
    start=weekly_rollover_start(); end=start+time.parse_duration("168h"); out=[]; seen={}
    for offset in [0,1,2,3,4,5,6,7]:
        d=start+time.parse_duration(str(offset*24)+"h"); key=d.format("20060102")
        for g in division_games(config,key):
            et=g["event_time"]
            if et==None or et<start or et>=end: continue
            k=g["away"]["id"]+"-"+g["home"]["id"]+"-"+et.format("200601021504")
            if seen.get(k)!=None: continue
            seen[k]=True; out.append(g)
    return out

def get_team_games(config,team_id):
    now=time.now().in_location("America/New_York"); year=now.year; data=fetch_json("https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/"+team_id+"/schedule?season="+str(year),30)
    if type(data)!="dict" or type(data.get("events"))!="list": return []
    tz=s(config.get("timezone"),"America/New_York"); out=[]
    for e in data.get("events"):
        g=parse_competition(e,tz)
        if g!=None: out.append(g)
    return out

def team_meta_record_from_game(g,team_id):
    if type(g)!="dict": return None
    if g["away"]["id"]==team_id: return {"meta":g["away"],"record":g["away_record"]}
    if g["home"]["id"]==team_id: return {"meta":g["home"],"record":g["home_record"]}
    return None
def make_bye_state(team_id,upcoming,latest_final):
    source=team_meta_record_from_game(upcoming,team_id)
    if source==None: source=team_meta_record_from_game(latest_final,team_id)
    if source==None: return None
    record=source["record"]; previous=team_meta_record_from_game(latest_final,team_id)
    if record=="" and previous!=None: record=previous["record"]
    return {"state":"bye","team":source["meta"],"record":record,"month_text":upcoming["month_text"],"day_text":upcoming["day_text"]}

def selected_games(config):
    mode=s(config.get("mode"),"team")
    if mode=="all": return games_in_cycle(config)
    team_id=s(config.get("team"),"")
    if team_id=="": return []
    start=weekly_rollover_start(); end=start+time.parse_duration("168h"); now=time.now().in_location("America/New_York"); games=get_team_games(config,team_id)
    for g in games:
        if g["state"]=="live": return [g]
    cycle=None
    for g in games:
        et=g["event_time"]
        if et==None or et<start or et>=end: continue
        if cycle==None or et<cycle["event_time"]: cycle=g
    if cycle!=None:
        fresh=division_games(config,cycle["event_time"].format("20060102"))
        for g in fresh:
            if g["away"]["id"]==cycle["away"]["id"] and g["home"]["id"]==cycle["home"]["id"]: return [g]
        return [cycle]
    upcoming=None; latest_final=None
    for g in games:
        et=g["event_time"]
        if et==None: continue
        if g["state"]=="final" and et<start and (latest_final==None or et>latest_final["event_time"]): latest_final=g
        elif g["state"]=="pre" and et>=now and (upcoming==None or et<upcoming["event_time"]): upcoming=g
    if latest_final==None and upcoming!=None: return [upcoming]
    if upcoming!=None:
        bye=make_bye_state(team_id,upcoming,latest_final)
        if bye!=None: return [bye]
    if latest_final!=None: return [latest_final]
    return []

def team_options():
    options=[]; seen={}
    for group in DIVISION_GROUPS:
        data=fetch_json("https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams?limit=500&groups="+str(group),21600)
        if type(data)!="dict": continue
        sports=data.get("sports")
        if type(sports)!="list" or len(sports)==0: continue
        leagues=sports[0].get("leagues") if type(sports[0])=="dict" else None
        if type(leagues)!="list" or len(leagues)==0: continue
        teams=leagues[0].get("teams") if type(leagues[0])=="dict" else None
        if type(teams)!="list": continue
        for wrapper in teams:
            team=wrapper.get("team") if type(wrapper)=="dict" else None
            if type(team)!="dict": continue
            tid=s(team.get("id"),""); name=s(team.get("displayName"),"")
            if tid=="" or name=="" or seen.get(tid)!=None: continue
            seen[tid]=True; options.append(schema.Option(display=name,value=tid))
    return options

def cycle_delay(config):
    value=s(config.get("all_games_cycle_time"),"8"); return {"3":3000,"4":4000,"5":5000,"6":6000,"8":8000,"10":10000,"12":12000,"15":15000}.get(value,8000)
def no_game(): return render.Root(child=render.Box(color=BLACK,width=64,height=32,child=centered_panel_text("NO NCAA GAME",32,"5x8",WHITE)))
def main(config):
    games=selected_games(config)
    if len(games)==0: return no_game()
    frames=[]
    for g in games: frames.append(render_game(g,config))
    if len(frames)==1: return render.Root(child=frames[0])
    return render.Root(delay=cycle_delay(config),show_full_animation=True,child=render.Animation(children=frames))

def get_schema():
    return schema.Schema(version="1",fields=[
        schema.Dropdown(id="mode",name="Game Mode",desc="Track one Division I school or cycle all Division I games.",icon="gear",default="team",options=[schema.Option(display="Specific Team",value="team"),schema.Option(display="All Games",value="all")]),
        schema.Dropdown(id="team",name="Team Focus",desc="FBS or FCS school used in Specific Team mode.",icon="gear",default="213",options=team_options()),
        schema.Dropdown(id="all_games_cycle_time",name="All Games Cycle Time",desc="Seconds each game is shown while cycling All Games.",icon="gear",default="8",options=[schema.Option(display="3 seconds",value="3"),schema.Option(display="4 seconds",value="4"),schema.Option(display="5 seconds",value="5"),schema.Option(display="6 seconds",value="6"),schema.Option(display="8 seconds",value="8"),schema.Option(display="10 seconds",value="10"),schema.Option(display="12 seconds",value="12"),schema.Option(display="15 seconds",value="15")]),
        schema.Color(id="pregame_date_color",name="Pregame Date Color",desc="Pregame weekday/date color.",icon="brush",default=WHITE),
        schema.Color(id="pregame_time_color",name="Pregame Time Color",desc="Pregame kickoff-time color.",icon="brush",default=WHITE),
        schema.Color(id="quarter_color",name="Quarter Color",desc="Live-game quarter color.",icon="brush",default=WHITE),
        schema.Color(id="clock_color",name="Clock Color",desc="Live-game clock color.",icon="brush",default=WHITE),
        schema.Color(id="field_color",name="Field Position Color",desc="Reserved to match NFL Game settings.",icon="brush",default=WHITE),
        schema.Color(id="final_color",name="Final Color",desc="Final-state text color.",icon="brush",default=WHITE),
    ])