//+------------------------------------------------------------------+
//|                                                   SAR_Expert.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//#property version   "0.02"
#include <Trade\Trade.mqh>
//--- input parameters
input ENUM_TIMEFRAMES timeframe = PERIOD_M30;
input int positionTotal=2;
input int hourStart=0;
input int minuteStart = 0;
input double lotSize = 0.01;
input double stopLoss=0.0015;
input double takeProfit=0.0060;
input double    greenStart=-1;
input double    redStart=-1;
input double blueStart = -1;
input bool blueLine = true; // czy użyć niebieskiej lini
input bool startWithTrade = false;
         //Jak nie chcesz żeby przy inicjalizacji SAR był w trade ustaw na false
         // bo inaczej jak jest w 2 kropce SAR zawsze będzie Trade

bool longOrShort; // decyduje czy bot działa w trybie longowania czy shortowania
//bool timeForTrading = true;

int sarHandle;
double green;
double red;
double blue;
double sar[3];
CTrade trade;
datetime openCandle, openCandlePrev;

MqlDateTime date, datePrevious;
MqlTick getPrice;
// Switche
bool preventTrade = false; // uniemożliwia trade
bool blueSwitch = false; // Wartość od której zacznie handlować
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if (greenStart>redStart) longOrShort = true; //long trade mode
   else if (greenStart<redStart) longOrShort = false; // short trade mode
   else {
      Print("GreenStart and RedStart have improper values"); 
      return(INIT_PARAMETERS_INCORRECT);
   }
   if (greenStart<0 || redStart<0){
      Print("GreenStart and RedStart have improper values"); 
      return(INIT_PARAMETERS_INCORRECT);
   }
   if (blueStart < 0 && blueLine == true){
      Print("Blue has wrong value"); 
      return(INIT_PARAMETERS_INCORRECT);
   }
   sarHandle = iSAR(_Symbol,timeframe,0.02,0.2);
   TimeCurrent(datePrevious);
   preventTrade = false;
   green = greenStart;
   red = redStart;
   blue = blueStart;
   //zczytuję świeczkę przy inicjalizacji bota
   if (startWithTrade == false) openCandlePrev = iTime(_Symbol,timeframe,0);
   else openCandlePrev = iTime(_Symbol,timeframe,1);
//---
   Print("Initialization Succeeded");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   TimeCurrent(date);
   openCandle = iTime(_Symbol,timeframe,0);
   createLine("green",green,clrGreen);
   createLine("red",red,clrRed);
   createLine("blue",blue,clrBlue);
   if(preventTrade == true) return;
   SymbolInfoTick(_Symbol, getPrice);
   double askPrice = getPrice.ask;
   preventTrade = checkLimits(green,red, askPrice, longOrShort);
   if (preventTrade == true){ 
      Print("preventTrade == true");
      return;
      }
   //-------------------------------- Jak dotknie nieb linii z automatu wleci trade
   if (blueSwitch == false && blueLine == true){
      blueSwitch = checkBlueLine(blue, blueLine, askPrice, longOrShort);
      if (blueSwitch == false) return;
      CopyBuffer(sarHandle,0,0,3,sar); 
      double previousPrice1 = iClose(_Symbol,timeframe,1);
      double previousPrice2 = iClose(_Symbol,timeframe,2);
      //if (longOrShort) performTrade(1, trade, previousPrice1, stopLoss, takeProfit);
      //else performTrade(-1, trade, previousPrice1, stopLoss, takeProfit);
      Print("Blue line triggered");
      //return;
   }
   //-------------------------------- ale nie chce mi się z tego robić kolejnej funkcji
   if(openCandlePrev == openCandle) return;
   openCandlePrev = openCandle;
   CopyBuffer(sarHandle,0,0,3,sar); 
   double previousPrice1 = iClose(_Symbol,timeframe,1);
   double previousPrice2 = iClose(_Symbol,timeframe,2);
   if (PositionsTotal()>=positionTotal) return;
   int tradeType = checkForTrade(preventTrade, longOrShort, sar, previousPrice1,previousPrice2, date);
   
   //int performTrade = performTrade(tradeType, trade, askPrice, stopLoss, takeProfit);
   int performTrade = performTrade(tradeType, trade, previousPrice1, stopLoss, takeProfit);
   if (performTrade != 0){ 
      changeLimits(green,red, trade.RequestTP(), trade.RequestSL(), longOrShort); 
      performTrade=0;
   }
  }

int checkForTrade(bool checkLimit, bool shortOrLong, double& sarArray[], double prevPrice1, double prevPrice2, MqlDateTime& dateCurrent)
{
   if (checkLimit == true) return 0; // Raczej potrzebne inaczej, wejdzie przynajmniej raz nawet jak wejdzie w limit
   if(shortOrLong == true) // long trade
   {
      //sprawdzam czy sar jest powyżej czy poniżej dwóch ostatnich świeczek (nie obecnej)
      if((sar[1] < prevPrice1) && (sar[0] > prevPrice2) ){ printf("Long trade at %02d:%02d ", date.hour,date.min); return 1;}//long trade
      else return 0;
   }
   else// short trade
   {
      if((sar[1] > prevPrice1) && (sar[0] < prevPrice2)) {printf("Short Trade at %02d:%02d", date.hour,date.min); return -1;}//short  trade
      else return 0;
   }
}

int performTrade(int tradeType, CTrade& insertTrade, double askPrice, double sl, double tp){
   if (tradeType == 1){
      bool res = insertTrade.Buy(lotSize,_Symbol, askPrice, askPrice-stopLoss, askPrice + takeProfit);
      if(res && insertTrade.ResultRetcode()==TRADE_RETCODE_DONE) Print(trade.ResultDeal());
      printf("askPrice: %e, stopLoss: %e, takeProfit: %e",askPrice, askPrice-stopLoss, askPrice + takeProfit);
      return 1;
   }
   else if (tradeType == -1){
      bool res = insertTrade.Sell(lotSize,_Symbol, askPrice, askPrice+stopLoss, askPrice - takeProfit);
      if(res && insertTrade.ResultRetcode()==TRADE_RETCODE_DONE) Print(trade.ResultDeal());
      return -1;
   }
   else return 0;
}

bool checkLimits(double Limit1, double Limit2, double askPrice, bool shortOrLong){
   if (shortOrLong == true) { //long
      if (askPrice > Limit1 || askPrice < Limit2) return true;
   }
   else if (shortOrLong == false) { //short
      if (askPrice < Limit1 || askPrice > Limit2) return true;
   }
   return false;
}

bool changeLimits(double& Limit1, double& Limit2, double priceTP, double priceSL, bool shortOrLong){
   if (shortOrLong == true){ //long trade (?)
      if(priceTP>Limit1) Limit1=priceTP;
      //if(priceSL>Limit2) Limit2=priceSL;
      return true;   
   }
   else { //short trade
      if(priceTP<Limit1) Limit1=priceTP;//teraz zadziała?
      //if(priceSL<Limit2) Limit2=priceSL;
      return true; 
   }
}
bool closeAllPositions(){
   
   for(int i =PositionsTotal()-1; i>=0; i--){
      int positionTicket=0;
      positionTicket=PositionGetTicket(i);
      bool res = trade.PositionClose(positionTicket);
      if(res && trade.ResultRetcode()==TRADE_RETCODE_DONE) Print(trade.ResultDeal());
      }   
   return true;
}

void createLine(string lineName, double valueOnChart,long colorValue){
   ObjectDelete(_Symbol,lineName);
   ObjectCreate(_Symbol,lineName,OBJ_HLINE,0,TimeCurrent(),valueOnChart); //Tworzymy linię
   ObjectSetInteger(0,lineName,OBJPROP_COLOR, colorValue); //Nadajemy jej własność koloru
   ObjectSetInteger(0,lineName,OBJPROP_WIDTH,1); //Nadajemy jej szerokość

}

bool checkBlueLine(double valueOfBlueLine, bool isBlueLineOn, double askPrice, bool shortOrLong){
   if (isBlueLineOn == false) return true;
   if (shortOrLong == true){
      if(askPrice <= valueOfBlueLine) return false;
      else return true;
   }
   else{
      if(askPrice >= valueOfBlueLine) return false;
      else return true;
   }
}

bool testing(int startingHour, int startingMinute, int hour, int minute){
    if (hour < startingHour) return false;
       if (hour >= startingHour){
          if (hour == startingHour && minute <startingMinute ) return false;
          else return true;
          }
      else return true;
   }