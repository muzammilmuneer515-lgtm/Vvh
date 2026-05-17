-- neu update
require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.content.*"
import "android.net.Uri"
import "android.graphics.*"
import "android.speech.tts.TextToSpeech"
import "android.media.MediaPlayer"

activity.getActionBar().hide()

prefs = activity.getSharedPreferences("userdata", 0)
editor = prefs.edit()

-- Default Sound Settings
if not prefs.contains("vol_bgm3") then
  editor.putInt("vol_click", 50).putBoolean("sw_click", true)
  editor.putInt("vol_play", 50).putBoolean("sw_play", true)
  editor.putInt("vol_shuffle", 50).putBoolean("sw_shuffle", true)
  editor.putInt("vol_win", 50).putBoolean("sw_win", true)
  editor.putInt("vol_lose", 50).putBoolean("sw_lose", true)
  editor.putInt("vol_bgm1", 50).putBoolean("sw_bgm1", true)
  editor.putInt("vol_bgm2", 50).putBoolean("sw_bgm2", true)
  editor.putInt("vol_bgm3", 15).putBoolean("sw_bgm3", true)
  editor.putInt("vol_bgm4", 50).putBoolean("sw_bgm4", true)
  editor.apply()
end

-- Sound Paths
local clickSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/click.mp3"
local cardPlaySound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/Play Card.mp3"
local shuffleSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/card_shuffle.mp3"
local winSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/Vin sound.mp3"
local loseSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/laugh4.mp3"
local bgm1Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM.ogg"
local bgm2Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 2.ogg"
local bgm3Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 3.ogg"
local bgm4Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 4.ogg"

local bgmPlayer = nil
local currentBgmPath = ""
local wasPlayingBeforePause = false

function getVol(key)
  return prefs.getInt("vol_"..key, 50) / 100
end

function playBGM(path)
  local key = ""
  if path == bgm1Path then key="bgm1" elseif path == bgm2Path then key="bgm2" 
  elseif path == bgm3Path then key="bgm3" elseif path == bgm4Path then key="bgm4" end
  
  if not prefs.getBoolean("sw_"..key, true) then 
    stopBGM()
    return 
  end

  if currentBgmPath == path and bgmPlayer ~= nil and bgmPlayer.isPlaying() then
    bgmPlayer.setVolume(getVol(key), getVol(key))
    return 
  end
  
  if bgmPlayer ~= nil then
    bgmPlayer.stop()
    bgmPlayer.release()
    bgmPlayer = nil
  end
  
  currentBgmPath = path
  bgmPlayer = MediaPlayer()
  bgmPlayer.setDataSource(path)
  bgmPlayer.setLooping(true)
  bgmPlayer.prepare()
  bgmPlayer.setVolume(getVol(key), getVol(key))
  bgmPlayer.start()
end

function stopBGM()
  if bgmPlayer ~= nil then
    if bgmPlayer.isPlaying() then
      bgmPlayer.stop()
    end
    bgmPlayer.release()
    bgmPlayer = nil
    currentBgmPath = ""
  end
end

-- Lifecycle Management for Home/Recent Buttons
function onPause()
  if bgmPlayer ~= nil and bgmPlayer.isPlaying() then
    bgmPlayer.pause()
    wasPlayingBeforePause = true
  end
end

function onResume()
  if bgmPlayer ~= nil and wasPlayingBeforePause then
    bgmPlayer.start()
    wasPlayingBeforePause = false
  end
end

function onDestroy()
  stopBGM()
  if tts then
    tts.shutdown()
  end
end

function playSound(path)
  local key = ""
  if path == clickSound then key="click" elseif path == cardPlaySound then key="play"
  elseif path == shuffleSound then key="shuffle" elseif path == winSound then key="win"
  elseif path == loseSound then key="lose" end
  
  if not prefs.getBoolean("sw_"..key, true) then return end

  pcall(function()
    local mp = MediaPlayer()
    mp.setDataSource(path)
    mp.prepare()
    local v = getVol(key)
    mp.setVolume(v, v)
    mp.start()
    mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{
      onCompletion=function(v)
        v.release()
      end
    })
  end)
end

function onKeyDown(code, event)
  if code == KeyEvent.KEYCODE_BACK then
    if isGameActive then
      showQuitGameDialog()
    else
      showExitDialog()
    end
    return true
  end
  return false
end

function showExitDialog()
  AlertDialog.Builder(activity)
    .setTitle("Exit")
    .setMessage("Are you really want to exit?")
    .setPositiveButton("Yes",{onClick=function() 
      stopBGM()
      activity.finish() 
    end})
    .setNegativeButton("No",nil)
    .show()
end

function showQuitGameDialog()
  AlertDialog.Builder(activity)
    .setTitle("Quit Game")
    .setMessage("Are you really want to quit? Your progress will be lost.")
    .setPositiveButton("Yes",{onClick=function()
      stopBGM()
      isGameActive = false
      mainUI() 
    end})
    .setNegativeButton("No",nil)
    .show()
end

function whiteText(v) v.setTextColor(Color.WHITE) end
function styleButton(btn)
  btn.setTextColor(Color.BLACK)
  btn.setBackgroundColor(Color.WHITE)
end

function wrapClick(btn, func)
  btn.onClick=function(v)
    playSound(clickSound)
    if func then func(v) end
  end
end

local tts
tts = TextToSpeech(activity, TextToSpeech.OnInitListener{
  onInit=function(status)
    if status == TextToSpeech.SUCCESS then
      local loc = luajava.bindClass("java.util.Locale")
      tts.setLanguage(loc.US)
    end
  end
})

function ttsAnnounce(text)
  if tts then
    tts.speak(text, TextToSpeech.QUEUE_FLUSH, nil, nil)
  end
end

local deck = {}
local playerHand = {}
local computerHand = {}
local board = {}
local isPlayerTurn = true
local cardsToGive = 0
isGameActive = false

local GradientDrawableClass = luajava.bindClass("android.graphics.drawable.GradientDrawable")
local bg = GradientDrawableClass()
bg.setGradientType(GradientDrawableClass.RADIAL_GRADIENT)
bg.setGradientRadius(1200)
bg.setColors({0xFF2E7D32, 0xFF1B5E20, 0xFF0A2A0A})

function mainUI()
  isGameActive = false
  playBGM(bgm2Path) 
  local savedName = prefs.getString("username", "Guest")

  local main_layout = {
    FrameLayout,
    layout_width="fill",
    layout_height="fill",
    background="#000000",
    {
      LinearLayout,
      orientation="vertical",
      layout_width="fill",
      gravity="center",
      layout_marginTop="60dp",
      {TextView,id="title",text="Card Games",textSize="28sp"},
      {TextView,id="userLabel",text="Welcome, "..savedName,textSize="14sp",textColor="#AAAAAA",layout_marginTop="5dp"},
      {TextView,id="version",text="Version 1.1",layout_marginTop="5dp"},
    },
    {
      LinearLayout,
      layout_width="wrap",
      layout_height="wrap",
      layout_gravity="top|right",
      padding="10dp",
      {Button,id="moreOptionsBtn",text="More Options",textSize="12sp"},
    },
    {
      LinearLayout,
      orientation="vertical",
      layout_width="fill",
      layout_height="wrap",
      layout_gravity="bottom",
      layout_marginBottom="80dp",
      padding="20dp",
      {Button,id="gamesMenuBtn",text="Games Menu",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="aboutBtn",text="About",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="creditsBtn",text="Credits",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="exitBtn",text="Exit",layout_width="fill"},
    },
  }

  activity.setContentView(loadlayout(main_layout))
  whiteText(title); title.setTypeface(Typeface.DEFAULT_BOLD)
  whiteText(version); userLabel.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.ITALIC))
  styleButton(moreOptionsBtn); styleButton(gamesMenuBtn); styleButton(aboutBtn); styleButton(creditsBtn); styleButton(exitBtn)

  wrapClick(creditsBtn, function()
    playBGM(bgm1Path) 
    local layoutC={
      ScrollView,
      layout_width="fill",
      layout_height="fill",
      background="#111111",
      {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        gravity="center",
        padding="25dp",
        {TextView, text="CREDITS", textSize="25sp", textColor="#FFD700", gravity="center", layout_marginBottom="20dp"},
        {TextView, text="this pRoject is created by YouTube production Studio", textSize="16sp", textColor="#00E5FF", gravity="center"},
        {TextView, text="where passion meets the world.", textSize="14sp", textColor="#00E5FF", gravity="center", layout_marginBottom="15dp"},
        {TextView, text=" Here you can see the names of those who helped create this project and made the project better and better", textSize="13sp", textColor="#AAAAAA", gravity="center", layout_marginBottom="25dp"},
        {TextView, text="developed by.", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="muzammil muneer", textSize="18sp", textColor="#00FF00", gravity="center", layout_marginBottom="15dp"},
        {TextView, text="helped in development.", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="bilawal pirzada", textSize="18sp", textColor="#00E5FF", gravity="center", layout_marginBottom="15dp"},
        {TextView, text="sound designed by.", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="irtiza hassan", textSize="18sp", textColor="#FF69B4", gravity="center", layout_marginBottom="15dp"},
        {TextView, text="Tested by.", textSize="12sp", textColor="#FFFFFF", gravity="center", layout_marginBottom="5dp"},
        {TextView, text="muhammad shuraim", textSize="17sp", textColor="#FFD700", gravity="center"},
        {TextView, text="muhammad hussain", textSize="17sp", textColor="#FFD700", gravity="center"},
        {TextView, text="irtiza hassan", textSize="17sp", textColor="#FFD700", gravity="center"},
        {TextView, text="bilawal pirzada", textSize="17sp", textColor="#FFD700", gravity="center", layout_marginBottom="30dp"},
        {TextView, text="thanks for playing", textSize="15sp", textColor="#FFFFFF", gravity="center", layout_marginBottom="20dp"},
        {Button, id="closeCreditsBtn", text="Back", layout_width="fill"},
      }
    }
    local vc = loadlayout(layoutC); styleButton(closeCreditsBtn)
    local dc = AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).create()
    dc.setView(vc); dc.show()
    wrapClick(closeCreditsBtn, function() 
      dc.dismiss()
      playBGM(bgm2Path) 
    end)
  end)

  wrapClick(gamesMenuBtn, function()
    playBGM(bgm4Path)
    local layoutGM={ LinearLayout, orientation="vertical", background="#000000", layout_width="fill", gravity="center", padding="20dp", {TextView, id="gmHead", text="Select Your Game", textSize="18sp", layout_marginBottom="20dp"}, {Button,id="playCardBtn",text="beggar my neighbor",layout_width="fill",layout_marginBottom="15dp"}, {Button,id="backToHomeBtn",text="Back to Home",layout_width="fill"}}
    local vgm = loadlayout(layoutGM); whiteText(gmHead); styleButton(playCardBtn); styleButton(backToHomeBtn); local dgm = AlertDialog.Builder(activity).create(); dgm.setTitle("Games Menu"); dgm.setView(vgm); dgm.show()
    
    wrapClick(playCardBtn, function()
      dgm.dismiss()
      local lobbyLayout = {
        LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill", background="#000000", gravity="center", padding="20dp",
        {TextView, text="Welcome", textSize="30sp", textColor="#FFD700", layout_marginBottom="10dp", gravity="center"},
        {TextView, text="Get Ready for the Challenge", textSize="16sp", textColor="#FFFFFF", layout_marginBottom="40dp", gravity="center"},
        {Button, id="startGameBtn", text="Start Game", layout_width="fill", layout_marginBottom="20dp"},
        {Button, id="backToMenuBtn", text="Back", layout_width="fill"}
      }
      activity.setContentView(loadlayout(lobbyLayout))
      styleButton(startGameBtn); styleButton(backToMenuBtn)
      wrapClick(startGameBtn, function() 
        playBGM(bgm3Path) 
        gameMainUI() 
      end)
      wrapClick(backToMenuBtn, function() mainUI() end)
    end)
    
    wrapClick(backToHomeBtn, function() 
      dgm.dismiss() 
      playBGM(bgm2Path)
    end)
    
    dgm.setOnCancelListener({onCancel=function() playBGM(bgm2Path) end})
  end)

  wrapClick(aboutBtn, function()
    playBGM(bgm1Path) 
    local layoutA={ 
      ScrollView, 
      layout_width="fill", 
      { 
        LinearLayout, 
        orientation="vertical", 
        background="#000000", 
        layout_width="fill", 
        gravity="center", 
        padding="16dp", 
        {TextView,id="aboutText",text="This tool is developed by Muzammil Muneer",layout_marginBottom="20dp"}, 
        {Button,id="ytBtn",text="Subscribe our YouTube channel Tech with Gamers",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="ytBtn2",text="Subscribe our YouTube channel Digital World For Blind",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="ytBtn3",text="Subscribe our other YouTube channel Hussain Urdu Adab",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="waChannelBtn",text="Follow our WhatsApp channel Digital World For Blind",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="waCommunityBtn",text="Join our WhatsApp community Digital World For Blind",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="feedbackBtn",text="Send Feedback",layout_width="fill",layout_marginBottom="10dp"}, 
        {Button,id="closeAboutBtn",text="Close",layout_width="fill"} 
      } 
    }
    local v=loadlayout(layoutA); whiteText(aboutText)
    styleButton(ytBtn); styleButton(ytBtn2); styleButton(ytBtn3); styleButton(waChannelBtn); styleButton(waCommunityBtn); styleButton(feedbackBtn); styleButton(closeAboutBtn)
    local d=AlertDialog.Builder(activity).create(); d.setTitle("About"); d.setView(v); d.show()
    wrapClick(ytBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@tecwithgamers"))) end)
    wrapClick(ytBtn2, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@digitalworldforblind"))) end)
    wrapClick(ytBtn3, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@hussainurduadab"))) end)
    wrapClick(waChannelBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://whatsapp.com/channel/0029VatVug4IHphAok7ffs2O"))) end)
    wrapClick(waCommunityBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://chat.whatsapp.com/LunAppbWT8UL5Tubw7vfYM"))) end)
    wrapClick(feedbackBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/923323905725"))) end)
    wrapClick(closeAboutBtn, function() 
      d.dismiss()
      playBGM(bgm2Path) 
    end)
  end)

  wrapClick(exitBtn, function() showExitDialog() end)
  
  -- More Options Logic
  wrapClick(moreOptionsBtn, function()
    stopBGM() 
    local layoutMO={ LinearLayout, orientation="vertical", background="#000000", layout_width="fill", gravity="center", padding="16dp",
      {TextView, id="moHead", text="More Options", textSize="20sp", textColor="#FFFFFF", layout_marginBottom="20dp"},
      {Button,id="settingsBtn",text="Settings",layout_width="fill", layout_marginBottom="10dp"},
      {Button,id="backToMainBtn",text="Back to main screen",layout_width="fill"}
    }
    local view=loadlayout(layoutMO); styleButton(settingsBtn); styleButton(backToMainBtn); local dialog1=AlertDialog.Builder(activity).create(); dialog1.setView(view); dialog1.show()
    wrapClick(backToMainBtn, function() dialog1.dismiss(); mainUI() end)
    dialog1.setOnCancelListener({onCancel=function() mainUI() end}) 

    wrapClick(settingsBtn, function()
      dialog1.dismiss(); local layoutS={ LinearLayout, orientation="vertical", background="#000000", layout_width="fill", gravity="center", padding="16dp",
        {TextView,id="settingsText",text="Settings",textSize="20sp",layout_marginBottom="20dp"},
        {Button,id="userProfileBtn",text="User Profile Settings",layout_width="fill", layout_marginBottom="10dp"},
        {Button,id="soundSettingsBtn",text="Sound Settings",layout_width="fill", layout_marginBottom="10dp"},
        {Button,id="backToMoreBtn",text="Back",layout_width="fill"}
      }
      local v1=loadlayout(layoutS); whiteText(settingsText); styleButton(userProfileBtn); styleButton(soundSettingsBtn); styleButton(backToMoreBtn); local dialog2=AlertDialog.Builder(activity).create(); dialog2.setView(v1); dialog2.show()
      
      wrapClick(backToMoreBtn, function() dialog2.dismiss(); moreOptionsBtn.performClick() end)
      
      -- USER PROFILE SETTINGS
      wrapClick(userProfileBtn, function()
        dialog2.dismiss(); local layoutP={ LinearLayout, orientation="vertical", background="#000000", layout_width="fill", gravity="center", padding="16dp", {Button,id="changeNameBtn",text="Change Username",layout_width="fill",layout_marginBottom="15dp"}, {Button,id="closeProfileBtn",text="Close",layout_width="fill"}}
        local v2=loadlayout(layoutP); styleButton(changeNameBtn); styleButton(closeProfileBtn); local dialog3=AlertDialog.Builder(activity).create(); dialog3.setTitle("User Profile Settings"); dialog3.setView(v2); dialog3.show()
        wrapClick(changeNameBtn, function() AlertDialog.Builder(activity).setTitle("Confirm").setMessage("Are you really want to change your username?").setPositiveButton("Yes",{onClick=function() stopBGM(); editor.remove("username"); editor.apply(); dialog3.dismiss(); welcome1() end}).setNegativeButton("No",nil).show() end)
        wrapClick(closeProfileBtn, function() dialog3.dismiss(); settingsBtn.performClick() end)
      end)

      -- SOUND SETTINGS
      wrapClick(soundSettingsBtn, function()
        dialog2.dismiss()
        local function createSoundRow(labelName, key)
          return {
            LinearLayout, orientation="vertical", layout_width="fill", layout_marginBottom="15dp",
            {
              LinearLayout, layout_width="fill", orientation="horizontal", gravity="center_vertical",
              {TextView, text=labelName, textColor="#FFFFFF", layout_weight="1"},
              {Switch, id="sw_"..key},
            },
            {
              SeekBar, id="sk_"..key, layout_width="fill", max=100
            }
          }
        end

        local sound_layout = {
          ScrollView, layout_width="fill", background="#000000",
          {
            LinearLayout, orientation="vertical", padding="16dp",
            {TextView, text="Sound Settings", textSize="22sp", textColor="#FFD700", gravity="center", layout_marginBottom="20dp"},
            createSoundRow("Click Sound", "click"),
            createSoundRow("Play Card Sound", "play"),
            createSoundRow("Shuffle Sound", "shuffle"),
            createSoundRow("Win Sound", "win"),
            createSoundRow("Lose Sound", "lose"),
            createSoundRow("Background Music 1", "bgm1"),
            createSoundRow("Background Music 2", "bgm2"),
            createSoundRow("Background Music 3", "bgm3"),
            createSoundRow("Background Music 4", "bgm4"),
            {Button, id="saveSoundBtn", text="Back & Save", layout_width="fill", layout_marginTop="20dp"}
          }
        }

        local vs = loadlayout(sound_layout)
        styleButton(saveSoundBtn)
        local ds = AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).create()
        ds.setView(vs); ds.show()

        local keys = {"click","play","shuffle","win","lose","bgm1","bgm2","bgm3","bgm4"}
        for _, k in ipairs(keys) do
          _G["sw_"..k].Checked = prefs.getBoolean("sw_"..k, true)
          _G["sk_"..k].Progress = prefs.getInt("vol_"..k, 50)
        end

        wrapClick(saveSoundBtn, function()
          for _, k in ipairs(keys) do
            editor.putBoolean("sw_"..k, _G["sw_"..k].Checked)
            editor.putInt("vol_"..k, _G["sk_"..k].Progress)
          end
          editor.apply()
          ds.dismiss()
          mainUI() 
        end)
      end)
    end)
  end)
end

-- Game logic functions
function setupDeck()
  deck = {}
  local suits = {{n="Hearts", s="♥", c="#FF0000"}, {n="Diamonds", s="♦", c="#FF0000"}, {n="Clubs", s="♣", c="#000000"}, {n="Spades", s="♠", c="#000000"}}
  for _, suit in ipairs(suits) do
    for i=2, 10 do table.insert(deck, {name=i, suit=suit.s, color=suit.c, fullName=i.." of "..suit.n, value=0, type="normal"}) end
    table.insert(deck, {name="A", suit=suit.s, color=suit.c, fullName="Ace of "..suit.n, value=4, type="special"})
    table.insert(deck, {name="K", suit=suit.s, color=suit.c, fullName="King of "..suit.n, value=3, type="special"})
    table.insert(deck, {name="Q", suit=suit.s, color=suit.c, fullName="Queen of "..suit.n, value=2, type="special"})
    table.insert(deck, {name="J", suit=suit.s, color=suit.c, fullName="Jack of "..suit.n, value=1, type="special"})
  end
  math.randomseed(os.time())
  for i = #deck, 2, -1 do local j = math.random(i); deck[i], deck[j] = deck[j], deck[i] end
  playerHand, computerHand = {}, {}
  for i=1, 52 do if i <= 26 then table.insert(playerHand, deck[i]) else table.insert(computerHand, deck[i]) end end
  isPlayerTurn, cardsToGive, board = true, 0, {}
end

function showResultDialog(title, message)
  local dialogLayout = {
    LinearLayout, orientation="vertical", layout_width="fill", background="#FFFFFF", padding="20dp", gravity="center",
    {TextView,id="resMsg",text=message,textSize="18sp",textColor="#000000",gravity="center",layout_marginBottom="20dp"},
    {LinearLayout, layout_width="fill", gravity="center",
      {Button,id="retryBtn",text="PLAY AGAIN",layout_width="0dp",layout_weight="1"},
      {Button,id="backBtn",text="BACK",layout_width="0dp",layout_weight="1",layout_marginLeft="10dp"}
    }
  }
  local builder = AlertDialog.Builder(activity); local v = loadlayout(dialogLayout)
  styleButton(retryBtn); styleButton(backBtn); resMsg.setTypeface(Typeface.DEFAULT_BOLD); builder.setView(v); builder.setCancelable(false)
  resultDlg = builder.create(); resultDlg.show()
  wrapClick(retryBtn, function() resultDlg.dismiss(); gameMainUI() end)
  wrapClick(backBtn, function() resultDlg.dismiss(); mainUI() end)
end

function createCardUI(idPrefix)
  return { CardView, id=idPrefix.."Card", layout_width="115dp", layout_height="165dp", cardBackgroundColor="#FFFFFF", cardElevation="15dp", radius="12dp", visibility=View.INVISIBLE,
    { RelativeLayout, layout_width="fill", layout_height="fill", padding="8dp",
      {TextView,id=idPrefix.."TopLabel",textSize="22sp",layout_alignParentTop=true,layout_alignParentLeft=true},
      {TextView,id=idPrefix.."MainSuit",textSize="55sp",layout_centerInParent=true} } }
end

function gameMainUI()
  isGameActive = true
  local game_layout = {
    RelativeLayout, layout_width="fill", layout_height="fill", id="gameView",
    {TextView,id="statusLabel",text="Card Game",textSize="20sp",textColor="#FFD700",layout_centerHorizontal=true,layout_marginTop="40dp"},
    {LinearLayout, layout_width="fill", gravity="center", layout_centerInParent=true,
      {LinearLayout, orientation="vertical", gravity="center", layout_marginRight="10dp", {TextView, text="Computer", textColor="#FFFFFF", layout_marginBottom="10dp", textSize="14sp"}, createCardUI("comp")},
      {LinearLayout, orientation="vertical", gravity="center", layout_marginLeft="10dp", {TextView, text="You", textColor="#FFFFFF", layout_marginBottom="10dp", textSize="14sp"}, createCardUI("play")} },
    {LinearLayout, id="bottomBar", layout_width="fill", layout_height="100dp", layout_alignParentBottom=true, padding="15dp", gravity="center",
      {CardView, layout_width="0dp", layout_weight="1", layout_height="60dp", radius="8dp", cardBackgroundColor="#FFFFFF", layout_marginRight="8dp", {Button,id="playBtn",text="PLAY CARD",background="#00000000",textColor="#000000"}},
      {CardView, layout_width="0dp", layout_weight="1", layout_height="60dp", radius="8dp", cardBackgroundColor="#FFFFFF", layout_marginLeft="8dp", {LinearLayout, layout_width="fill", layout_height="fill", gravity="center", orientation="vertical", {TextView,id="cardCountLabel",text="",textColor="#000000",textSize="11sp",gravity="center"}}} },
    {TextView,id="boardText",text="",layout_above="bottomBar",layout_centerHorizontal=true,textColor="#FFFFFF",layout_marginBottom="10dp",textSize="16sp"}
  }
  activity.setContentView(loadlayout(game_layout))
  gameView.setBackground(bg); statusLabel.setTypeface(Typeface.DEFAULT_BOLD); cardCountLabel.setTypeface(Typeface.DEFAULT_BOLD)
  task(300, function() playSound(shuffleSound) end)
  wrapClick(playBtn, function() playTurn() end)
  setupDeck(); updateUI("Game Ready! Your Turn")
end

function updateCardGraphics(card, side)
  local cardView, topText, mainSuitText
  if side == "play" then cardView, topText, mainSuitText = playCard, playTopLabel, playMainSuit else cardView, topText, mainSuitText = compCard, compTopLabel, compMainSuit end
  if card then
    cardView.setVisibility(View.VISIBLE); topText.Text = tostring(card.name).." "..card.suit; mainSuitText.Text = card.suit
    local c = Color.parseColor(card.color); topText.setTextColor(c); mainSuitText.setTextColor(c); topText.setTypeface(Typeface.DEFAULT_BOLD)
  end
end

function updateUI(msg)
  statusLabel.Text = msg; cardCountLabel.Text = "Your Cards: "..#playerHand.."\nComputer Cards: "..#computerHand; boardText.Text = "Pile: "..#board.." cards"
end

function awardBoard(winnerHand)
  for _, c in ipairs(board) do table.insert(winnerHand, c) end
  board, cardsToGive = {}, 0; playCard.setVisibility(View.INVISIBLE); compCard.setVisibility(View.INVISIBLE)
end

function checkGameOver()
  if #playerHand == 0 or #computerHand == 0 then
    if #playerHand == 0 and cardsToGive > 0 then awardBoard(computerHand) elseif #computerHand == 0 and cardsToGive > 0 then awardBoard(playerHand) end
    if #playerHand == 0 then
      updateUI("Match Over"); playSound(loseSound); showResultDialog("Match Over", "Computer Win, Better Luck Next Time")
      return true
    elseif #computerHand == 0 then
      updateUI("Match Over"); playSound(winSound); showResultDialog("Match Over", "Congratulations! You Win")
      return true
    end
  end
  return false
end

function playTurn()
  if checkGameOver() then return end
  local currentHand = isPlayerTurn and playerHand or computerHand
  local opponentHand = isPlayerTurn and computerHand or playerHand
  local playedCard = table.remove(currentHand, 1)
  if not playedCard then return end
  playSound(cardPlaySound)
  table.insert(board, playedCard); updateCardGraphics(playedCard, isPlayerTurn and "play" or "comp")
  local name = isPlayerTurn and "You" or "Computer"; local msg = name.." played "..playedCard.fullName; ttsAnnounce(msg)
  if playedCard.type == "special" then
    cardsToGive = playedCard.value; isPlayerTurn = not isPlayerTurn; updateUI(msg..". Give "..cardsToGive.." cards")
  elseif cardsToGive > 0 then
    cardsToGive = cardsToGive - 1
    if cardsToGive == 0 then
      local winnerMsg = "Pile collected by "..(isPlayerTurn and "Computer" or "You"); updateUI(winnerMsg)
      task(800, function() ttsAnnounce(winnerMsg) end)
      playBtn.Enabled = false; task(1800, function() awardBoard(opponentHand); updateUI("Pile collected"); isPlayerTurn = not isPlayerTurn; if not checkGameOver() then checkComputerTurn() end end)
      return
    else updateUI(msg..". "..cardsToGive.." more") end
  else isPlayerTurn = not isPlayerTurn; updateUI(msg) end
  checkComputerTurn()
end

function checkComputerTurn()
  if not isPlayerTurn then playBtn.Enabled = false; task(1500, function() if not checkGameOver() then playTurn() end end) else playBtn.Enabled = true end
end

function usernameScreen()
  isGameActive = false
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", padding="16dp", {TextView,id="txt",text="Create your username",gravity="center",textSize="18sp",layout_marginBottom="10dp"}, {EditText,id="nameInput",hint="Enter your username",textColor="#FFFFFF",hintTextColor="#AAAAAA",layout_width="fill",singleLine=true}, {LinearLayout, orientation="horizontal", layout_marginTop="20dp", {Button,id="cancelBtn",text="Cancel",layout_width="0dp",layout_weight="1"}, {Button,id="saveBtn",text="Save",layout_width="0dp",layout_weight="1"} } }
  activity.setContentView(loadlayout(layout))
  whiteText(txt); styleButton(cancelBtn); styleButton(saveBtn)
  wrapClick(cancelBtn, function() welcome2() end)
  wrapClick(saveBtn, function()
    local raw_uname = tostring(nameInput.getText())
    local uname = raw_uname:gsub("^%s*(.-)%s*$", "%1")
    if uname == "" then Toast.makeText(activity, "You have not entered any username yet", Toast.LENGTH_SHORT).show(); return end
    if not uname:match("^[a-zA-Z0-9_]+$") then AlertDialog.Builder(activity).setTitle("Invalid Username").setMessage("Sirf letters, numbers aur underscore (_) allowed hain.").setPositiveButton("OK", nil).show(); return end
    editor.putString("username", uname); editor.putBoolean("first_run", false); editor.apply(); mainUI()
  end)
end

function welcome2()
  isGameActive = false
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", {TextView,id="t2",text="This tool is developed by Muzammil Muneer",gravity="center",textSize="18sp"}, {Space, layout_height="20dp"}, {Button,id="n2",text="Next",layout_width="200dp"} }
  activity.setContentView(loadlayout(layout))
  whiteText(t2); styleButton(n2)
  wrapClick(n2, function() usernameScreen() end)
end

function welcome1()
  isGameActive = false
  playBGM(bgm1Path) 
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", {TextView,id="t1",text="Welcome to Card Games",gravity="center",textSize="22sp"}, {Space, layout_height="10dp"}, {TextView,id="t1sub",text="This tool is specially designed for visually impaired persons. Here you will find various types of card games to play and enjoy...",gravity="center",textSize="16sp",layout_marginLeft="20dp",layout_marginRight="20dp"}, {Space, layout_height="20dp"}, {Button,id="n1",text="Next",layout_width="200dp"} }
  activity.setContentView(loadlayout(layout))
  whiteText(t1); whiteText(t1sub); styleButton(n1)
  wrapClick(n1, function() welcome2() end)
end

if prefs.getBoolean("first_run", true) or prefs.getString("username", nil) == nil then
  welcome1()
else
  mainUI()
end
