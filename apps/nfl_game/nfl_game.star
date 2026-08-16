# NFL Game
# NFL counterpart to tronbyt/apps apps/mlb_game.
# Geometry intentionally follows MLB Game: 36px team panel + 28px info panel.

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

WHITE = "#ffffff"
BLACK = "#000000"

TEAM_BG = {
    "ARI":"#97233F", "ATL":"#A71930", "BAL":"#241773", "BUF":"#00338D", "CAR":"#0085CA", "CHI":"#0B162A", "CIN":"#FB4F14", "CLE":"#311D00",
    "DAL":"#003594", "DEN":"#FB4F14", "DET":"#0076B6", "GB":"#203731", "HOU":"#03202F", "IND":"#002C5F", "JAX":"#006778", "KC":"#E31837",
    "LV":"#111111", "LAC":"#0080C6", "LAR":"#003594", "MIA":"#008E97", "MIN":"#4F2683", "NE":"#002244", "NO":"#A08A58", "NYG":"#0B2265",
    "NYJ":"#125740", "PHI":"#004C54", "PIT":"#101820", "SF":"#AA0000", "SEA":"#002244", "TB":"#D50A0A", "TEN":"#0C2340", "WSH":"#5A1414",
}
TEAM_NAMES = {
    "ARI":"Arizona Cardinals", "ATL":"Atlanta Falcons", "BAL":"Baltimore Ravens", "BUF":"Buffalo Bills", "CAR":"Carolina Panthers", "CHI":"Chicago Bears", "CIN":"Cincinnati Bengals", "CLE":"Cleveland Browns",
    "DAL":"Dallas Cowboys", "DEN":"Denver Broncos", "DET":"Detroit Lions", "GB":"Green Bay Packers", "HOU":"Houston Texans", "IND":"Indianapolis Colts", "JAX":"Jacksonville Jaguars", "KC":"Kansas City Chiefs",
    "LV":"Las Vegas Raiders", "LAC":"Los Angeles Chargers", "LAR":"Los Angeles Rams", "MIA":"Miami Dolphins", "MIN":"Minnesota Vikings", "NE":"New England Patriots", "NO":"New Orleans Saints", "NYG":"New York Giants",
    "NYJ":"New York Jets", "PHI":"Philadelphia Eagles", "PIT":"Pittsburgh Steelers", "SF":"San Francisco 49ers", "SEA":"Seattle Seahawks", "TB":"Tampa Bay Buccaneers", "TEN":"Tennessee Titans", "WSH":"Washington Commanders",
}
THROWBACK = {
    "ATL":{"name":"Throwback","bg":"#A71930"}, "BUF":{"name":"Throwback","bg":"#00338D"}, "CHI":{"name":"1936 Throwback","bg":"#0B162A"}, "CLE":{"name":"Classic Throwback","bg":"#311D00"},
    "DAL":{"name":"Throwback","bg":"#002244"}, "DEN":{"name":"Orange Crush","bg":"#FB4F14"}, "DET":{"name":"Classic Throwback","bg":"#0076B6"}, "GB":{"name":"Classic Throwback","bg":"#203731"},
    "JAX":{"name":"Prowler Throwback","bg":"#006778"}, "MIA":{"name":"Throwback","bg":"#008E97"}, "MIN":{"name":"Classic Throwback","bg":"#4F2683"}, "NE":{"name":"Pat Patriot","bg":"#C60C30"},
    "NYG":{"name":"Classic Throwback","bg":"#0B2265"}, "NYJ":{"name":"Legacy Throwback","bg":"#125740"}, "PHI":{"name":"Kelly Green","bg":"#004953"}, "PIT":{"name":"1933 Throwback","bg":"#101820"},
    "SF":{"name":"94 Throwback","bg":"#AA0000"}, "SEA":{"name":"90s Throwback","bg":"#69BE28"}, "TB":{"name":"Creamsicle","bg":"#FF7900"}, "TEN":{"name":"Oilers Throwback","bg":"#418FDE"}, "WSH":{"name":"Super Bowl Era","bg":"#5A1414"},
}
THROWBACK_SCHEDULE = {"2026": {}}

def spacer_w(w): return render.Box(width=w, height=1)
def spacer_h(h): return render.Box(width=1, height=h)
def s(v, d=""): return v if v != None and type(v) == "string" else d
def i(v, d=0): return v if v != None and type(v) == "int" else d

def score_int(v):
    if type(v) == "int": return v
    if type(v) == "string" and v != "":
        for n in range(0, 100):
            if v == str(n): return n
    return 0

def fetch_json(url, ttl=30):
    r = http.get(url=url, ttl_seconds=ttl)
    if r.status_code != 200: return None
    b = r.body()
    if b == None or len(b) == 0 or b[0] != "{": return None
    return json.decode(b)

def logo_bytes(url):
    if url == "": return None
    r = http.get(url=url, ttl_seconds=36000)
    return r.body() if r.status_code == 200 else None

def team_meta(team):
    if type(team) != "dict": return {"code":"NFL","bg":"#202020","logo":""}
    code = s(team.get("abbreviation"), "NFL")
    col = s(team.get("color"), "")
    if col != "" and col[0] != "#": col = "#" + col
    if col == "" or col == "#000000" or col == "#ffffff": col = TEAM_BG.get(code, "#202020")
    return {"code":code, "bg":col, "logo":s(team.get("logo"), "")}

def record_text(competitor):
    if type(competitor) != "dict": return ""
    records = competitor.get("records")
    if type(records) != "list" or len(records) == 0: return ""
    for record in records:
        if type(record) == "dict" and s(record.get("summary"), "") != "": return s(record.get("summary"), "")
    return ""

def logo_node(meta, width, height=None):
    if height == None: height = width
    img = logo_bytes(meta["logo"])
    if img != None: return render.Image(img, width=width, height=height)
    return render.Text(meta["code"][0], font="6x13", color=WHITE)

def game_team_tile(meta, score, possession, live):
    logo_width = 17 if live else 20
    info_width = 15
    logo = logo_node(meta, logo_width, 16)
    if live:
        possession_box = render.Box(width=2, height=9, child=render.Column(children=[render.Box(width=2, height=2, color=WHITE) if possession else spacer_w(2)], main_align="center", cross_align="center"))
        score_row = render.Box(width=info_width, height=9, child=render.Row(children=[
            spacer_w(2),
            render.Box(width=11, height=9, child=render.Row(children=[render.Text(str(score), font="5x8", color=WHITE)], main_align="center", cross_align="center")),
            possession_box,
        ], main_align="start", cross_align="center"))
    else:
        score_row = render.Box(width=info_width, height=9, child=render.Row(children=[render.Text(str(score), font="5x8", color=WHITE)], main_align="center", cross_align="center"))
    info = render.Box(width=info_width, height=16, child=render.Column(children=[
        render.Box(width=info_width, height=7, child=render.Row(children=[render.Text(meta["code"], font="tom-thumb", color=WHITE)], main_align="center", cross_align="center")),
        score_row,
    ], main_align="start", cross_align="stretch"))
    if live:
        return render.Box(color=meta["bg"], width=36, height=16, child=render.Row(children=[
            render.Box(width=17, height=16, child=render.Row(children=[logo], main_align="center", cross_align="center")), spacer_w(1), info,
        ], main_align="start", cross_align="center"))
    return render.Box(color=meta["bg"], width=36, height=16, child=render.Row(children=[
        render.Box(width=20, height=16, child=render.Row(children=[logo], main_align="center", cross_align="center")), spacer_w(1), info,
    ], main_align="start", cross_align="center"))

def shifted_team_text(text, width, height, font):
    return render.Box(width=width, height=height, child=render.Row(children=[
        spacer_w(1),
        render.Box(width=width-1, height=height, child=render.Row(children=[render.Text(text, font=font, color=WHITE)], main_align="center", cross_align="center")),
    ], main_align="start", cross_align="center"))

def shifted_team_text_down(text, width, height, font):
    return render.Box(width=width, height=height, child=render.Column(children=[
        spacer_h(1),
        render.Box(width=width, height=height-1, child=render.Row(children=[
            spacer_w(1),
            render.Box(width=width-1, height=height-1, child=render.Row(children=[render.Text(text, font=font, color=WHITE)], main_align="center", cross_align="center")),
        ], main_align="start", cross_align="center")),
    ], main_align="start", cross_align="stretch"))

def pregame_team_column(meta, record, width):
    logo = logo_node(meta, width, 18)
    return render.Box(color=meta["bg"], width=width, height=32, child=render.Column(children=[
        shifted_team_text_down(meta["code"], width, 6, "tom-thumb"),
        render.Box(width=width, height=18, child=render.Row(children=[logo], main_align="center", cross_align="center")),
        shifted_team_text(record, width, 8, "CG-pixel-3x5-mono"),
    ], main_align="start", cross_align="stretch"))

def left_panel(g):
    live = g["state"] == "live"
    return render.Box(width=36, child=render.Column(children=[
        game_team_tile(g["away"], g["away_score"], g["possession"] == g["away"]["code"], live),
        game_team_tile(g["home"], g["home_score"], g["possession"] == g["home"]["code"], live),
    ]))

def centered_panel_text(text, height, font, color):
    return render.Box(width=28, height=height, child=render.Row(children=[
        spacer_w(1), render.Box(width=27, height=height, child=render.Row(children=[render.Text(text, font=font, color=color)], main_align="center", cross_align="center")),
    ], main_align="start", cross_align="center"))

def field_position_text(text, height, font, color):
    return render.Box(width=28, height=height, child=render.Row(children=[
        spacer_w(2), render.Box(width=26, height=height, child=render.Row(children=[render.Text(text, font=font, color=color)], main_align="center", cross_align="center")),
    ], main_align="start", cross_align="center"))

def compact_preview_row(text, width, height, font, color):
    return render.Box(width=width, height=height, child=render.Column(children=[
        render.Row(children=[render.Text(text, font=font, color=color)], main_align="center", cross_align="center"),
    ], main_align="center", cross_align="stretch"))

def pregame_date_row(month, day, color, width):
    left_width = (width // 2) + 1
    right_width = width - left_width
    return render.Box(width=width, height=8, child=render.Row(children=[
        render.Box(width=left_width, height=8, child=render.Row(children=[spacer_w(1), render.Text(month, font="tom-thumb", color=color), spacer_w(1)], main_align="end", cross_align="center")),
        render.Box(width=right_width, height=8, child=render.Row(children=[spacer_w(2), render.Text(day, font="tom-thumb", color=color)], main_align="start", cross_align="center")),
    ], main_align="start", cross_align="center"))

def pregame_time_row(hour, minute, color, width):
    colon = render.Box(width=1, height=8, child=render.Column(children=[
        spacer_h(1), render.Box(width=1, height=1, color=color), spacer_h(2), render.Box(width=1, height=1, color=color), spacer_h(3),
    ], main_align="start", cross_align="center"))
    return render.Box(width=width, height=15, child=render.Column(children=[
        spacer_h(2),
        render.Box(width=width, height=13, child=render.Row(children=[
            render.Text(hour, font="5x8", color=color), spacer_w(1), colon, spacer_w(1), render.Text(minute, font="5x8", color=color),
        ], main_align="center", cross_align="center")),
    ], main_align="start", cross_align="stretch"))

def preview_panel(g, config, width=28):
    date_color = s(config.get("pregame_date_color"), WHITE)
    time_color = s(config.get("pregame_time_color"), WHITE)
    return render.Box(width=width, height=32, child=render.Column(children=[
        spacer_h(1),
        compact_preview_row(g["weekday_text"], width, 7, "tom-thumb", date_color),
        pregame_date_row(g["month_text"], g["day_text"], date_color, width),
        pregame_time_row(g["clock_hour"], g["clock_minute"], time_color, width),
        spacer_h(1),
    ], main_align="start", cross_align="stretch"))

def live_clock_row(clock, color):
    parts = clock.split(":")
    if len(parts) != 2: return centered_panel_text(clock, 10, "5x8", color)
    colon = render.Box(width=1, height=8, child=render.Column(children=[
        spacer_h(2), render.Box(width=1, height=1, color=color), spacer_h(2), render.Box(width=1, height=1, color=color), spacer_h(2),
    ], main_align="start", cross_align="center"))
    return render.Box(width=28, height=10, child=render.Row(children=[
        render.Text(parts[0], font="5x8", color=color), spacer_w(1), colon, spacer_w(1), render.Text(parts[1], font="5x8", color=color),
    ], main_align="center", cross_align="center"))

def live_panel(g, config):
    qc=s(config.get("quarter_color"),WHITE); tc=s(config.get("clock_color"),WHITE); fc=s(config.get("field_color"),WHITE)
    return render.Box(width=28, height=32, child=render.Column(children=[
        spacer_h(4),
        centered_panel_text(g["quarter"], 6, "tom-thumb", qc),
        live_clock_row(g["clock"], tc),
        spacer_h(4),
        field_position_text(g["field_position"], 8, "CG-pixel-3x5-mono", fc),
    ], main_align="start", cross_align="stretch"))

def final_panel(config):
    return render.Box(width=28, height=32, child=render.Column(children=[
        centered_panel_text("FINAL", 32, "5x8", s(config.get("final_color"),WHITE)),
    ], main_align="center", cross_align="stretch"))

def render_game(g, config):
    if g["state"] == "pre":
        return render.Box(color=BLACK, width=64, height=32, child=render.Row(children=[
            pregame_team_column(g["away"], g["away_record"], 21),
            preview_panel(g, config, 22),
            pregame_team_column(g["home"], g["home_record"], 21),
        ], main_align="start", cross_align="start"))
    right = live_panel(g, config) if g["state"] == "live" else final_panel(config)
    return render.Box(color=BLACK, child=render.Row(children=[left_panel(g), right], main_align="start", cross_align="start"))

def parse_competition(event, timezone):
    comps = event.get("competitions") if type(event) == "dict" else None
    if type(comps) != "list" or len(comps) == 0: return None
    comp = comps[0]; competitors = comp.get("competitors")
    if type(competitors) != "list": return None
    away=None; home=None; away_score=0; home_score=0; away_record=""; home_record=""; away_id=""; home_id=""
    for c in competitors:
        if type(c) != "dict": continue
        team=c.get("team")
        m = team_meta(team)
        cid=s(c.get("id"), "")
        if cid=="" and type(team)=="dict": cid=s(team.get("id"), "")
        if s(c.get("homeAway")) == "away": away=m; away_score=score_int(c.get("score")); away_record=record_text(c); away_id=cid
        if s(c.get("homeAway")) == "home": home=m; home_score=score_int(c.get("score")); home_record=record_text(c); home_id=cid
    if away == None or home == None: return None
    status=event.get("status"); stype=status.get("type") if type(status)=="dict" else {}
    state_raw=s(stype.get("state")) if type(stype)=="dict" else "pre"
    state="live" if state_raw=="in" else ("final" if state_raw=="post" else "pre")
    display_clock=s(status.get("displayClock"),"") if type(status)=="dict" else ""; period=i(status.get("period"),0) if type(status)=="dict" else 0
    quarter=""
    if period==1: quarter="1st"
    elif period==2: quarter="2nd"
    elif period==3: quarter="3rd"
    elif period==4: quarter="4th"
    elif period>4: quarter="OT"
    situation=comp.get("situation"); possession=""; down_distance=""; field_position=""
    if type(situation)=="dict":
        possession_raw=s(situation.get("possession"),"")
        if possession_raw==away_id: possession=away["code"]
        elif possession_raw==home_id: possession=home["code"]
        elif possession_raw==away["code"] or possession_raw==home["code"]: possession=possession_raw
        down_distance=s(situation.get("shortDownDistanceText"),s(situation.get("downDistanceText"),"")); field_position=s(situation.get("possessionText"),"")
    date_raw=s(event.get("date"),""); weekday_text="TBD"; date_text="TBD"; month_text=""; day_text=""; clock_text="TBD"; clock_hour=""; clock_minute=""
    if date_raw!="":
        parse_date=date_raw
        if len(date_raw)==17 and date_raw[16]=="Z": parse_date=date_raw[:16]+":00Z"
        t=time.parse_time(parse_date).in_location(timezone)
        weekday_text=t.format("Mon").upper()
        month_text=t.format("Jan").upper()
        day_text=t.format("2")
        date_text=month_text+" "+day_text
        clock_text=t.format("3:04")
        clock_hour=t.format("3")
        clock_minute=t.format("04")
    return {"away":away,"home":home,"away_score":away_score,"home_score":home_score,"away_record":away_record,"home_record":home_record,"state":state,"quarter":quarter,"clock":display_clock,"possession":possession,"down_distance":down_distance,"field_position":field_position,"weekday_text":weekday_text,"date_text":date_text,"month_text":month_text,"day_text":day_text,"clock_text":clock_text,"clock_hour":clock_hour,"clock_minute":clock_minute}

def get_games(config):
    data=fetch_json("https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?limit=100",30)
    if type(data)!="dict": return []
    events=data.get("events")
    if type(events)!="list": return []
    tz=s(config.get("timezone"),"America/New_York")
    games=[]
    for event in events:
        g=parse_competition(event,tz)
        if g!=None: games.append(g)
    return games

def selected_games(config):
    games=get_games(config); mode=s(config.get("mode"),"team")
    if mode=="all": return games
    team=s(config.get("team"),"PHI"); out=[]
    for g in games:
        if g["away"]["code"]==team or g["home"]["code"]==team: out.append(g)
    return out

def no_game():
    return render.Root(child=render.Box(color=BLACK,width=64,height=32,child=render.Column(children=[spacer_h(10),render.Box(width=64,child=render.Row(children=[render.Text("NO NFL GAME",font="5x8",color=WHITE)],main_align="center"))],cross_align="stretch")))

def main(config):
    games=selected_games(config)
    if len(games)==0: return no_game()
    frames=[]
    for g in games: frames.append(render_game(g,config))
    if len(frames)==1: return render.Root(child=frames[0])
    return render.Root(delay=8000,child=render.Animation(children=frames))

def get_schema():
    return schema.Schema(version="1",fields=[
        schema.Dropdown(id="mode",name="Game Mode",desc="Track one team or cycle all NFL games.",icon="gear",default="team",options=[schema.Option(display="Specific Team",value="team"),schema.Option(display="All Games",value="all")]),
        schema.Dropdown(id="team",name="Team Focus",desc="Team used in Specific Team mode.",icon="gear",default="PHI",options=teamOptions),
        schema.Color(id="pregame_date_color",name="Pregame Date Color",desc="Pregame weekday/date color.",icon="brush",default=WHITE), schema.Color(id="pregame_time_color",name="Pregame Time Color",desc="Pregame kickoff-time color.",icon="brush",default=WHITE),
        schema.Color(id="quarter_color",name="Quarter Color",desc="Live-game quarter color.",icon="brush",default=WHITE),
        schema.Color(id="clock_color",name="Clock Color",desc="Live-game clock color.",icon="brush",default=WHITE),
        schema.Color(id="field_color",name="Field Position Color",desc="Live-game field position color.",icon="brush",default=WHITE), schema.Color(id="final_color",name="Final Color",desc="Final-state text color.",icon="brush",default=WHITE),
    ])

teamOptions=[schema.Option(display=TEAM_NAMES[k],value=k) for k in TEAM_NAMES]