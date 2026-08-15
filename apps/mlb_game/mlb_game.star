# MLB Game scoreboard for Tronbyt
# Based on tronbyt/apps mlb_game, with pregame games allowed before linescore data exists.

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

def spacer_w(w):
    return render.Box(width = w, height = 1)

def spacer_h(h):
    return render.Box(width = 1, height = h)

def px(c):
    return render.Box(width = 1, height = 1, color = c)

def clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

def as_str(x, d):
    return x if (x != None and type(x) == "string") else d

def as_int(x, d):
    return x if (x != None and type(x) == "int") else d

def as_bool(x, d):
    return x if (x != None and type(x) == "bool") else d

def as_text(x, d):
    if x == None:
        return d
    if type(x) == "string":
        return x
    if type(x) == "int":
        return str(x)
    return d

def int_from_digits(s, d):
    if type(s) != "string" or len(s) == 0:
        return d
    for i in range(len(s)):
        if s[i] < "0" or s[i] > "9":
            return d
    return int(s)

def default_game():
    return {
        "away": "PIT", "home": "PHI", "ascore": 0, "hscore": 0,
        "inning": "1", "top": True, "balls": 0, "strikes": 0, "outs": 0,
        "on1": False, "on2": False, "on3": False,
        "away_bg": "#27251F", "home_bg": "#E81828",
        "away_logo_url": "", "home_logo_url": "",
        "is_final": False, "is_preview": False, "start_text": "",
        "game_label": "", "has_game": False, "fetch_ok": False,
    }

TEAM_BY_ID = {
    108:"LAA",109:"ARI",110:"BAL",111:"BOS",112:"CHC",113:"CIN",114:"CLE",115:"COL",
    116:"DET",117:"HOU",118:"KC",119:"LAD",120:"WSH",121:"NYM",133:"ATH",134:"PIT",
    135:"SD",136:"SEA",137:"SF",138:"STL",139:"TB",140:"TEX",141:"TOR",142:"MIN",
    143:"PHI",144:"ATL",145:"CWS",146:"MIA",147:"NYY",158:"MIL",
}
TEAM_ID_BY_CODE = {
    "LAA":108,"ARI":109,"AZ":109,"BAL":110,"BOS":111,"CHC":112,"CIN":113,"CLE":114,
    "COL":115,"DET":116,"HOU":117,"KC":118,"LAD":119,"WSH":120,"NYM":121,"ATH":133,
    "PIT":134,"SD":135,"SEA":136,"SF":137,"STL":138,"TB":139,"TEX":140,"TOR":141,
    "MIN":142,"PHI":143,"ATL":144,"CWS":145,"MIA":146,"NYY":147,"MIL":158,
}
TEAM_BG = {
    "ARI":"#A71930","AZ":"#A71930","ATH":"#003831","ATL":"#CE1141","BAL":"#DF4601",
    "BOS":"#BD3039","CHC":"#0E3386","CIN":"#C6011F","CLE":"#0C2340","COL":"#333366",
    "CWS":"#27251F","DET":"#0C2340","HOU":"#002D62","KC":"#004687","LAA":"#BA0021",
    "LAD":"#005A9C","MIA":"#00A3E0","MIL":"#12284B","MIN":"#002B5C","NYM":"#002D72",
    "NYY":"#132448","PHI":"#E81828","PIT":"#27251F","SD":"#2F241D","SEA":"#0C2C56",
    "SF":"#FD5A1E","STL":"#C41E3A","TB":"#092C5C","TEX":"#003278","TOR":"#134A8E","WSH":"#AB0003",
}
ALT_COLOR = {"HOU":"#002D62","LAD":"#005A9C","WSH":"#AB0003","PIT":"#111111"}
ALT_LOGO = {
    "PHI":"https://b.fssta.com/uploads/application/mlb/team-logos/Phillies-alternate.png",
    "DET":"https://b.fssta.com/uploads/application/mlb/team-logos/Tigers-alternate.png",
    "CIN":"https://b.fssta.com/uploads/application/mlb/team-logos/Reds-alternate.png",
    "STL":"https://b.fssta.com/uploads/application/mlb/team-logos/Cardinals-alternate.png",
}
TEAM_LOGO_KEY = {
    "ARI":"ari","AZ":"ari","ATH":"oak","ATL":"atl","BAL":"bal","BOS":"bos","CHC":"chc","CIN":"cin",
    "CLE":"cle","COL":"col","CWS":"chw","DET":"det","HOU":"hou","KC":"kc","LAA":"laa","LAD":"lad",
    "MIA":"mia","MIL":"mil","MIN":"min","NYM":"nym","NYY":"nyy","PHI":"phi","PIT":"pit","SD":"sd",
    "SEA":"sea","SF":"sf","STL":"stl","TB":"tb","TEX":"tex","TOR":"tor","WSH":"wsh",
}
LOGO_SIZE = {"ARI":18,"ATL":18,"CWS":22,"DET":18,"HOU":18,"LAA":22,"LAD":18,"MIA":18,"NYM":18,"SF":18,"SEA":18,"TOR":18}
HEX_VAL = {"0":0,"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,"a":10,"b":11,"c":12,"d":13,"e":14,"f":15,"A":10,"B":11,"C":12,"D":13,"E":14,"F":15}

def lookup_team_code(team):
    if type(team) != "dict": return "MLB"
    code = as_str(team.get("abbreviation"), "")
    if code != "": return code
    tid = as_int(team.get("id"), 0)
    if TEAM_BY_ID.get(tid) != None: return TEAM_BY_ID.get(tid)
    name = as_str(team.get("name"), "MLB")
    return name[:3] if len(name) >= 3 else name

def is_hex_digit(ch): return HEX_VAL.get(ch) != None

def normalize_hex_color(s):
    if type(s) != "string": return ""
    if len(s) == 6:
        for i in range(6):
            if not is_hex_digit(s[i]): return ""
        return "#" + s
    if len(s) == 7 and s[0] == "#":
        for i in range(1, 7):
            if not is_hex_digit(s[i]): return ""
        return s
    return ""

def team_bg_for(code, espn_color):
    c = as_str(code, "")
    col = normalize_hex_color(espn_color)
    alt = ALT_COLOR.get(c)
    if alt != None: col = alt
    elif col == "": col = TEAM_BG.get(c) if TEAM_BG.get(c) != None else "#202020"
    if col == "#ffffff" or col == "#000000": return "#222222"
    return col

def hex_byte(s, start):
    if type(s) != "string" or len(s) < start + 2: return 0
    hi = HEX_VAL.get(s[start]); lo = HEX_VAL.get(s[start + 1])
    if hi == None or lo == None: return 0
    return hi * 16 + lo

def team_font_color(bg):
    if type(bg) != "string" or len(bg) != 7: return "#ffffff"
    lum = (hex_byte(bg,1)*299 + hex_byte(bg,3)*587 + hex_byte(bg,5)*114) / 1000
    return "#111111" if lum >= 140 else "#ffffff"

def get_cachable_data(url, ttl_seconds):
    res = http.get(url = url, ttl_seconds = ttl_seconds)
    if res.status_code != 200: return None
    body = res.body()
    return body if body != None and len(body) > 0 else None

def logo_url_for(code, espn_logo_url):
    c = as_str(code, "")
    alt = ALT_LOGO.get(c)
    if alt != None: return alt
    url = as_str(espn_logo_url, "")
    if url != "":
        url = url.replace("500/scoreboard", "500-dark/scoreboard")
        return url.replace("https://a.espncdn.com/", "https://a.espncdn.com/combiner/i?img=")
    key = TEAM_LOGO_KEY.get(c)
    return "https://a.espncdn.com/i/teamlogos/mlb/500-dark/" + key + ".png" if key != None else ""

def get_espn_team_map():
    out = {}
    resp = http.get(url = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard?limit=100", ttl_seconds = 120)
    if resp.status_code != 200: return out
    body = resp.body()
    if body == None or len(body) == 0 or body[0] != "{": return out
    parsed = json.decode(body)
    if type(parsed) != "dict": return out
    events = parsed.get("events")
    if type(events) != "list": return out
    for ev in events:
        if type(ev) != "dict": continue
        comps = ev.get("competitions")
        if type(comps) != "list" or len(comps) == 0: continue
        comp = comps[0]
        if type(comp) != "dict": continue
        competitors = comp.get("competitors")
        if type(competitors) != "list": continue
        for ct in competitors:
            if type(ct) != "dict": continue
            team = ct.get("team")
            if type(team) != "dict": continue
            abbr = as_str(team.get("abbreviation"), "")
            if abbr == "": continue
            out[abbr] = {"color":normalize_hex_color(team.get("color")),"logo":as_str(team.get("logo"),"")}
    return out

def team_logo_sprite(code, fg, espn_logo_url):
    url = logo_url_for(code, espn_logo_url)
    if url != "":
        img = get_cachable_data(url, 36000)
        if img != None:
            size = LOGO_SIZE.get(code)
            if size == None: size = 16
            if size > 14: size = 14
            if size < 12: size = 12
            return render.Box(width = 14, height = 14, child = render.Row(children = [render.Image(img, width = size, height = size)], main_align = "center", cross_align = "center"))
    mark = code[:1] if type(code) == "string" and len(code) > 0 else "M"
    return render.Text(mark, font = "6x13", color = fg)

def get_mlb_team_ids():
    out = {}
    resp = http.get(url = "https://statsapi.mlb.com/api/v1/teams?sportId=1&activeStatus=Y", ttl_seconds = 86400)
    if resp.status_code == 200:
        body = resp.body()
        if body != None and len(body) > 0 and body[0] == "{":
            parsed = json.decode(body)
            if type(parsed) == "dict":
                teams = parsed.get("teams")
                if type(teams) == "list":
                    for team in teams:
                        if type(team) != "dict": continue
                        tid = as_int(team.get("id"), 0)
                        if tid > 0: out[tid] = True
    if len(out) == 0:
        for tid in TEAM_BY_ID: out[tid] = True
    return out

def is_public_facing_game(game):
    if type(game) != "dict": return False
    p = game.get("publicFacing")
    if p == None: return True
    if type(p) == "bool": return p
    if type(p) == "string": return p == "True"
    return True

def has_tracked_linescore(game):
    if type(game) != "dict": return False
    l = game.get("linescore")
    if type(l) != "dict": return False
    innings = l.get("innings")
    if type(innings) == "list" and len(innings) > 0: return True
    if l.get("currentInning") != None: return True
    teams = l.get("teams")
    if type(teams) == "dict":
        home = teams.get("home"); away = teams.get("away")
        if type(home) == "dict" and len(home) > 0: return True
        if type(away) == "dict" and len(away) > 0: return True
    offense = l.get("offense")
    if type(offense) == "dict" and (type(offense.get("batter")) == "dict" or type(offense.get("onDeck")) == "dict" or type(offense.get("inHole")) == "dict"): return True
    defense = l.get("defense")
    if type(defense) == "dict" and (type(defense.get("pitcher")) == "dict" or type(defense.get("catcher")) == "dict"): return True
    return False

def is_preview_game(game):
    if type(game) != "dict": return False
    status = game.get("status")
    if type(status) != "dict": return False
    state = as_str(status.get("abstractGameState"), "")
    detailed = as_str(status.get("detailedState"), "")
    return state == "Preview" or detailed == "Scheduled" or detailed == "Pre-Game"

def is_mlb_team(team, mlb_ids):
    if type(team) != "dict": return False
    tid = as_int(team.get("id"), 0)
    if mlb_ids.get(tid) != None: return True
    code = lookup_team_code(team)
    return TEAM_ID_BY_CODE.get(code) != None or TEAM_BG.get(code) != None

def has_only_mlb_opponents(game, mlb_ids):
    if type(game) != "dict": return False
    teams = game.get("teams")
    if type(teams) != "dict": return False
    away = teams.get("away"); home = teams.get("home")
    if type(away) != "dict" or type(home) != "dict": return False
    return is_mlb_team(away.get("team"), mlb_ids) and is_mlb_team(home.get("team"), mlb_ids)

def game_has_team_code(game, code):
    if code == "": return True
    if type(game) != "dict": return False
    teams = game.get("teams")
    if type(teams) != "dict": return False
    away = teams.get("away"); home = teams.get("home")
    at = away.get("team") if type(away) == "dict" else None
    ht = home.get("team") if type(home) == "dict" else None
    return lookup_team_code(at) == code or lookup_team_code(ht) == code

def game_sort_key(game):
    if type(game) != "dict": return 999
    num = as_int(game.get("gameNumber"), 0)
    if num > 0: return num
    gd = as_str(game.get("gameDate"), "")
    if len(gd) >= 16: return int_from_digits(gd[11:13],0)*60 + int_from_digits(gd[14:16],0)
    return 999

def game_rank(game):
    if type(game) != "dict": return -1
    status = game.get("status")
    if type(status) != "dict": return 0
    state = as_str(status.get("abstractGameState"), ""); detailed = as_str(status.get("detailedState"), "")
    if state == "Live": return 4
    if state == "Preview" or detailed == "Scheduled" or detailed == "Pre-Game": return 3
    if detailed == "Delayed Start" or detailed == "Postponed" or detailed == "Suspended": return 2
    if state == "Final": return 1
    return 0

def is_better_game(candidate, best):
    if type(candidate) != "dict": return False
    if type(best) != "dict": return True
    cr = game_rank(candidate); br = game_rank(best)
    if cr != br: return cr > br
    ck = game_sort_key(candidate); bk = game_sort_key(best)
    if cr <= 1: return ck > bk
    return ck < bk

def select_game_info(games, include_exhibition, mlb_ids, team_code):
    if type(games) != "list" or len(games) == 0: return None
    ordered = []
    for game in games:
        if type(game) != "dict": continue
        if not is_public_facing_game(game): continue
        if not is_preview_game(game) and not has_tracked_linescore(game): continue
        if not include_exhibition and not has_only_mlb_opponents(game, mlb_ids): continue
        if not game_has_team_code(game, team_code): continue
        insert_at = len(ordered); key = game_sort_key(game)
        for i in range(len(ordered)):
            if key < game_sort_key(ordered[i]): insert_at = i; break
        ordered.insert(insert_at, game)
    if len(ordered) == 0: return None
    first = ordered[0]
    if as_str(first.get("gameType"), "") != "R": return {"game":first,"game_label":""}
    best = ordered[0]; best_index = 1
    for i in range(len(ordered)):
        if is_better_game(ordered[i], best): best = ordered[i]; best_index = i + 1
    label = "G" + str(best_index) if len(ordered) > 1 else ""
    return {"game":best,"game_label":label}

def tz_suffix(tz):
    if tz == "America/New_York": return "ET"
    return ""

def format_start_text(game_date, timezone):
    if type(game_date) != "string" or len(game_date) < 16: return "TBD"
    # Always display game start times in Eastern Time. America/New_York automatically handles EST/EDT.
    tz = "America/New_York"
    parsed = time.parse_time(game_date).in_location(tz)
    return parsed.format("3:04") + " ET"

def base_diamond(filled):
    rows = []
    for y in range(7):
        pixels = []
        for x in range(7):
            distance = abs(x - 3) + abs(y - 3); color = "#000000"
            if distance == 3: color = "#ffffff"
            elif distance < 3 and filled: color = "#ffd24a"
            pixels.append(px(color))
        rows.append(render.Row(children = pixels, main_align = "start", cross_align = "start"))
    return render.Box(width = 7, height = 7, child = render.Column(children = rows, main_align = "start", cross_align = "start"))

def bases_tile(on1,on2,on3):
    return render.Box(height=16, child=render.Column(children=[spacer_h(1),render.Row(children=[base_diamond(on2)],main_align="center"),spacer_h(1),render.Row(children=[base_diamond(on3),spacer_w(3),base_diamond(on1)],main_align="center")],main_align="start",cross_align="center"))

def tiny_out_box(on): return render.Box(width=3,height=3,color="#ffd24a" if on else "#2a2a2a")
def outs_row(outs):
    outs=clamp(outs,0,2); return render.Row(children=[tiny_out_box(outs>=1),spacer_w(2),tiny_out_box(outs>=2)],main_align="center",cross_align="center")
def tiny_arrow(top_half):
    patterns=["..#..",".###.","#####"] if top_half else ["#####",".###.","..#.."]
    rows=[]
    for r in range(len(patterns)):
        pattern=patterns[r]; pixels=[]
        for i in range(len(pattern)): pixels.append(px("#ffffff" if pattern[i]=="#" else "#000000"))
        rows.append(render.Row(children=pixels,main_align="start",cross_align="start"))
    return render.Box(width=5,height=3,child=render.Column(children=rows,main_align="start",cross_align="start"))
def game_label_tile(label):
    if label=="": return bases_tile(False,False,False)
    return render.Box(height=16,child=render.Column(children=[spacer_h(4),render.Row(children=[render.Text(label,font="CG-pixel-3x5-mono")],main_align="center")],main_align="start",cross_align="center"))
def status_tile(text):
    child=render.Text(text,font="6x10-rounded")
    if len(text)>5: child=render.Text(text,font="5x8")
    return render.Box(height=16,width=29,child=render.Row(children=[child],expanded=True,main_align="center",cross_align="center"))
def count_tile(inning,top_half,balls,strikes,outs,label):
    left_top=[spacer_h(4)]
    if label!="": left_top=[spacer_h(1),render.Text(label,font="CG-pixel-3x5-mono"),spacer_h(1)]
    left=render.Box(width=10,height=16,child=render.Column(children=left_top+[render.Row(children=[render.Column(children=[spacer_h(3),tiny_arrow(top_half)]),spacer_w(1),render.Text(str(inning),font="5x8")],main_align="start")],main_align="start",cross_align="start"))
    right=render.Box(width=18,child=render.Column(children=[spacer_h(1),render.Row(children=[render.Text(str(balls)+"-"+str(strikes),font="5x8")],main_align="center"),spacer_h(1),render.Row(children=[outs_row(outs)],main_align="center")],main_align="start",cross_align="center"))
    return render.Box(height=16,child=render.Row(children=[spacer_w(1),left,right],main_align="start",cross_align="start"))
def team_tile(bg,code,score,logo_url):
    fg=team_font_color(bg)
    left=render.Box(width=14,child=render.Row(children=[team_logo_sprite(code,fg,logo_url)],main_align="center"))
    right=render.Box(width=15,child=render.Column(children=[render.Text(code,font="CG-pixel-3x5-mono",color=fg),spacer_h(2),render.Text(str(score),font="5x8",color=fg)],main_align="start",cross_align="start"))
    return render.Box(color=bg,height=16,padding=1,child=render.Row(children=[left,spacer_w(4),right],main_align="start",cross_align="center"))
def left_panel(data):
    return render.Box(width=36,child=render.Column(children=[team_tile(data["away_bg"],data["away"],data["ascore"],data["away_logo_url"]),team_tile(data["home_bg"],data["home"],data["hscore"],data["home_logo_url"])],main_align="start",cross_align="stretch"))
def right_panel(data):
    if data["is_final"] or data["is_preview"]:
        text="Final" if data["is_final"] else data["start_text"]
        return render.Box(width=28,child=render.Column(children=[game_label_tile(data["game_label"]),status_tile(text)],main_align="start",cross_align="stretch"))
    return render.Box(width=29,child=render.Column(children=[bases_tile(data["on1"],data["on2"],data["on3"]),count_tile(data["inning"],data["top"],data["balls"],data["strikes"],data["outs"],data["game_label"])],main_align="start",cross_align="stretch"))

def get_game_data(config):
    data=default_game(); espn=get_espn_team_map(); mlb_ids=get_mlb_team_ids()
    include_exhibition=config.bool("include_exhibition_opponents",False); team_code=as_str(config.get("team"),""); team_id=TEAM_ID_BY_CODE.get(team_code)
    if team_id==None: team_id=111
    response=http.get(url="https://statsapi.mlb.com/api/v1/schedule?sportId=1&teamId="+str(team_id)+"&hydrate=linescore",ttl_seconds=120)
    if response.status_code!=200: return data
    body=response.body()
    if body==None or len(body)==0 or body[0]!="{": return data
    parsed=json.decode(body)
    if type(parsed)!="dict": return data
    data["fetch_ok"]=True; dates=parsed.get("dates")
    if type(dates)!="list" or len(dates)==0: return data
    day=dates[0]
    if type(day)!="dict": return data
    info=select_game_info(day.get("games"),include_exhibition,mlb_ids,team_code)
    if type(info)!="dict": return data
    game=info.get("game")
    if type(game)!="dict": return data
    data["has_game"]=True; data["game_label"]=as_str(info.get("game_label"),"")
    status=game.get("status")
    if type(status)=="dict":
        state=as_str(status.get("abstractGameState"),""); detailed=as_str(status.get("detailedState"),"")
        data["is_final"]=state=="Final"; data["is_preview"]=state=="Preview" or detailed=="Scheduled" or detailed=="Pre-Game"
    if data["is_preview"]: data["start_text"]=format_start_text(as_str(game.get("gameDate"),""),None)
    teams=game.get("teams")
    if type(teams)=="dict":
        away_info=teams.get("away"); home_info=teams.get("home")
        if type(away_info)=="dict" and type(home_info)=="dict":
            away_code=lookup_team_code(away_info.get("team")); home_code=lookup_team_code(home_info.get("team")); away_meta=espn.get(away_code); home_meta=espn.get(home_code)
            away_color=as_str(away_meta.get("color"),"") if type(away_meta)=="dict" else ""; home_color=as_str(home_meta.get("color"),"") if type(home_meta)=="dict" else ""
            away_logo=as_str(away_meta.get("logo"),"") if type(away_meta)=="dict" else ""; home_logo=as_str(home_meta.get("logo"),"") if type(home_meta)=="dict" else ""
            data["away"]=away_code; data["home"]=home_code; data["ascore"]=as_int(away_info.get("score"),0); data["hscore"]=as_int(home_info.get("score"),0)
            data["away_bg"]=team_bg_for(away_code,away_color); data["home_bg"]=team_bg_for(home_code,home_color); data["away_logo_url"]=away_logo; data["home_logo_url"]=home_logo
    linescore=game.get("linescore")
    if type(linescore)=="dict":
        data["inning"]=as_text(linescore.get("currentInning"),1); data["top"]=as_bool(linescore.get("isTopInning"),True); data["balls"]=clamp(as_int(linescore.get("balls"),0),0,3); data["strikes"]=clamp(as_int(linescore.get("strikes"),0),0,2); data["outs"]=clamp(as_int(linescore.get("outs"),0),0,2)
        offense=linescore.get("offense")
        if type(offense)=="dict": data["on1"]=type(offense.get("first"))=="dict"; data["on2"]=type(offense.get("second"))=="dict"; data["on3"]=type(offense.get("third"))=="dict"
    return data

def main(config):
    data=get_game_data(config)
    if config.bool("gameday_only",False) and data["fetch_ok"] and not data["has_game"]: return []
    return render.Root(child=render.Box(color="#000000",child=render.Row(children=[left_panel(data),right_panel(data)],main_align="start",cross_align="start")))

def get_schema():
    return schema.Schema(version="1",fields=[schema.Dropdown(id="team",name="Team Focus",desc="Only show scores for selected team.",icon="gear",default="PHI",options=teamOptions),schema.Toggle(id="gameday_only",name="Show only on game day",desc="Hide app from rotation when no game is scheduled for selected team/date.",icon="calendar",default=False),schema.Toggle(id="include_exhibition_opponents",name="Include non-MLB opponents",desc="Show exhibitions against international, national, or other non-MLB teams.",icon="gear",default=False)])

teamOptions = [
    schema.Option(display="Arizona Diamondbacks",value="ARI"),schema.Option(display="Athletics",value="ATH"),schema.Option(display="Atlanta Braves",value="ATL"),schema.Option(display="Baltimore Orioles",value="BAL"),schema.Option(display="Boston Red Sox",value="BOS"),schema.Option(display="Chicago Cubs",value="CHC"),schema.Option(display="Chicago White Sox",value="CWS"),schema.Option(display="Cincinnati Reds",value="CIN"),schema.Option(display="Cleveland Guardians",value="CLE"),schema.Option(display="Colorado Rockies",value="COL"),schema.Option(display="Detroit Tigers",value="DET"),schema.Option(display="Houston Astros",value="HOU"),schema.Option(display="Kansas City Royals",value="KC"),schema.Option(display="Los Angeles Angels",value="LAA"),schema.Option(display="Los Angeles Dodgers",value="LAD"),schema.Option(display="Miami Marlins",value="MIA"),schema.Option(display="Milwaukee Brewers",value="MIL"),schema.Option(display="Minnesota Twins",value="MIN"),schema.Option(display="New York Mets",value="NYM"),schema.Option(display="New York Yankees",value="NYY"),schema.Option(display="Philadelphia Phillies",value="PHI"),schema.Option(display="Pittsburgh Pirates",value="PIT"),schema.Option(display="San Diego Padres",value="SD"),schema.Option(display="San Francisco Giants",value="SF"),schema.Option(display="Seattle Mariners",value="SEA"),schema.Option(display="St. Louis Cardinals",value="STL"),schema.Option(display="Tampa Bay Rays",value="TB"),schema.Option(display="Texas Rangers",value="TEX"),schema.Option(display="Toronto Blue Jays",value="TOR"),schema.Option(display="Washington Nationals",value="WSH")
]
