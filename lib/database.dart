import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:signin_signup_authentification/UserManager.dart';
import 'package:signin_signup_authentification/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DatabaseService{

  String uid="";
  DatabaseService(String m_uid){
    this.uid = m_uid;
  }
  final CollectionReference allUsers = FirebaseFirestore.instance.collection("allUsers");
  final CollectionReference allHelpers = FirebaseFirestore.instance.collection("allHelpers");
  final CollectionReference allFees = FirebaseFirestore.instance.collection("allFees");
  final CollectionReference allEarnings = FirebaseFirestore.instance.collection("allEarnings");
  final CollectionReference allSubscriptionsAndSubscribers = FirebaseFirestore.instance.collection("allSubscriptionsAndSubscribers");
  final CollectionReference allScheduledLives = FirebaseFirestore.instance.collection("allScheduledLives");
  final CollectionReference allChouchous = FirebaseFirestore.instance.collection("allChouchous");
  final CollectionReference allClientsReservationTasks = FirebaseFirestore.instance.collection("allClientsReservationTasks");


  Future updateUserData(String pseudo, String ? email /*String ? phone*/, int coinsToGive, String countryCode, bool appIsInMaintenance) async {

    String? token_id = await FirebaseMessaging.instance.getToken();

    final prefs = await SharedPreferences.getInstance();
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    String? voipToken = await prefs.getString("voipToken");

    Reference ref = FirebaseStorage.instance.ref();
    String defaultAvatarURL = await ref.child("default_images/default_avatar.png").getDownloadURL();

    Map dailyNotifications = {
      '00':[],
      '1':[],
      '2':[],
      '3':[],
      '4':[],
      '5':[],
      '6':[],
      '7':[],
      '8':[],
      '9':[],
      '10':[],
      '11':[],
      '12':[],
      '13':[],
      '14':[],
      '15':[],
      '16':[],
      '17':[],
      '18':[],
      '19':[],
      '20':[],
      '21':[],
      '22':[],
      '23':[],
    };

    Map scheduledNotifications = {
      'Monday':dailyNotifications,
      'Tuesday':dailyNotifications,
      'Wednesday':dailyNotifications,
      'Thursday':dailyNotifications,
      'Friday':dailyNotifications,
      'Saturday':dailyNotifications,
      'Sunday':dailyNotifications,
    };

    return await allUsers.doc(uid).set(
      {
        'created':DateTime.now().microsecondsSinceEpoch,
        'isAppTerminated':false,
        'appIsInMaintenance':appIsInMaintenance,
        'isIOS':Platform.isIOS,
        'apnsToken':apnsToken,
        'voipToken':voipToken,
        'allScheduledNotificationsTasks':scheduledNotifications,
        'userId':uid,
        'customerId':'',
        'subscriptionFailed':false,
        'subscriptionId':'',
        'subscriptionName':'',
        'maxVipHelpersThreshold':0,
        'vipHelpers':[],
        'customerEmail':email,
        'accountId':'',
        'countryCode':countryCode,
        'pseudo': pseudo,
        'telephone': "",
        'token_firebasemsg_id': token_id,
        'token_call_id': '',
        'calling_state': '0',
        'user_account_state': false,
        'whiteboard_id': '',
        'avatar_url': defaultAvatarURL,
        'live_status': LiveStatus.AVAILABLE,
        'peer_temporary_id': '',
        'channel_name_call_id': '',
        'last_helper_temporary_id':'',
        'last_duration_live':0,
        'last_role_live':'',
        'coins':coinsToGive,
        'last_time_live': "",
        'is_helper':false,
        'is_helper_certified':0,
        'first_name':'',
        'last_name':'',
        'is_new_user': true,
        'helper_earnings_not_certified_amount':"",
        'helper_earnings_temporary_amount':"",
        'temporaryCoins': 0 == coinsToGive ? -1 : 0,
        'spotPrice': g_africanCountriesCurrencies.keys.contains(countryCode) ? 6 : 10,
        'addedSpotPrice':[],
        'video_url':""
      }
    );
  }

  Future updateUserFees() async {

    var date = DateTime.now();
    Map<String, dynamic>? daysHistory = {};

    Map<String, dynamic>? monthlyHistory = {
      'estimatedAmount':'',
      'days':daysHistory
    };

    Map<String, dynamic>? annualHistoryMonths = {
      'January':monthlyHistory,
      'February':monthlyHistory,
      'March':monthlyHistory,
      'April':monthlyHistory,
      'May':monthlyHistory,
      'June':monthlyHistory,
      'July':monthlyHistory,
      'August':monthlyHistory,
      'September':monthlyHistory,
      'October':monthlyHistory,
      'November':monthlyHistory,
      'December':monthlyHistory,
    };

    Map<String, dynamic>? totalHistory = {
      date.year.toString():annualHistoryMonths
    };

    return await allFees.doc(uid).set(
        totalHistory,
        SetOptions(merge: true)
    );
  }

  Future updateUserSubscriptionsAndSubscribers() async {

    return await allSubscriptionsAndSubscribers.doc(uid).set(
        {
        'subscriptions':[],
        'subscribers':[]
        }
    );

  }

  Future updateUserHelper(Map<String, dynamic> form, UserManager p_userManager) async {

    List listOfNeededParams = ["avatar_url","token_firebasemsg_id","countryCode"];
    Map tmpValues = await p_userManager.getMultipleValues("allUsers", listOfNeededParams);
    String defaultAvatarURL = tmpValues[listOfNeededParams[0]];
    String token_id = tmpValues[listOfNeededParams[1]];
    String countryCode  = tmpValues[listOfNeededParams[2]];

    final CollectionReference allKeyWords = FirebaseFirestore.instance.collection((countryCode=="FR") ? "allKeyWords" : ("allKeyWords" + countryCode));

    if (!await p_userManager.checkIfDocExists("allHelpers", uid)){

      var date = DateTime.now().microsecondsSinceEpoch;
      await allUsers.doc(uid).update(
          {
            'is_helper':true,
            'first_name':form['first_name'],
            'last_name': form['last_name'],
          }
      );

      //Add keywords
      List tmpKeyWords = form["keywords"];
      List addedKeyWords = [];

      for(int i=0;i<tmpKeyWords.length;i++){
        var keyword = tmpKeyWords[i];
        if (!addedKeyWords.contains(keyword)){
          addedKeyWords.add(keyword);
          await allKeyWords.doc(keyword).set({
            "listOfUsers": FieldValue.arrayUnion([uid])
          },
              SetOptions(merge: true)
          );
        }
      }

      await allChouchous.doc(uid).set({
        "userId":uid,
        "created": date,
        "chouchous": []
      },
          SetOptions(merge: true)
      );


      return await allHelpers.doc(uid).set(
          {
            'created':date,
            'isUserActive':true,
            'avatar_url': defaultAvatarURL,
            'comments': 0,
            'keywords':addedKeyWords,
            'is_helper_certified':0,
            'first_name': form['first_name'],
            'last_name': form['last_name'],
            'presentation': form['presentation'],
            'likes': 1,
            'live_button_id': uid,
            'live_status': LiveStatus.AVAILABLE,
            'subscribers': 0,
            'token_firebasemsg_id': token_id,
            'numOfChouchous':0,
            'spotPrice':g_africanCountriesCurrencies.keys.contains(countryCode) ? 6 : 10,
            'countryCode':countryCode,
            'video_url':"",
            'addedSpotPrice':[]
          }
      );
    }
    else
    {
      List currentListOfKeyWords = await p_userManager.getValue("allHelpers", "keywords");

      for (int index=0;index<currentListOfKeyWords.length;index++){
        await allKeyWords.doc(currentListOfKeyWords[index]).set({
          "listOfUsers": FieldValue.arrayRemove([uid])
        },
            SetOptions(merge: true)
        );
      }

      //Add keywords
      List tmpKeyWords = form["keywords"];
      List addedKeyWords = [];
      for(int i=0;i<tmpKeyWords.length;i++){
        var keyword = tmpKeyWords[i];
        if (!addedKeyWords.contains(keyword)){
          addedKeyWords.add(keyword);
          await allKeyWords.doc(keyword).set({
            "listOfUsers": FieldValue.arrayUnion([uid])
          },
              SetOptions(merge: true)
          );
        }
      }

      return await allHelpers.doc(uid).update(
          {
            'keywords':addedKeyWords,
            'presentation': form['presentation'],
            //'competences': form['competences'],
          },
      );
    }

  }

  Future updateUserHelperEarnings(UserManager p_userManager) async {
    var date = DateTime.now();
    bool docExists = await p_userManager.checkIfDocExists("allEarnings", uid);
    if (!docExists){
      Map<String, dynamic>? daysHistory = {};
      Map<String, dynamic>? monthlyHistory = {
        'estimatedAmount':'',
        'days':daysHistory
      };

      Map<String, dynamic>? annualHistoryMonths = {
        'January':monthlyHistory,
        'February':monthlyHistory,
        'March':monthlyHistory,
        'April':monthlyHistory,
        'May':monthlyHistory,
        'June':monthlyHistory,
        'July':monthlyHistory,
        'August':monthlyHistory,
        'September':monthlyHistory,
        'October':monthlyHistory,
        'November':monthlyHistory,
        'December':monthlyHistory,
      };

      Map<String, dynamic>? totalHistory = {
        date.year.toString():annualHistoryMonths
      };

      return await allEarnings.doc(uid).set(
          totalHistory,
          SetOptions(merge: true)
      );
    }

  }

  Future updateUserHelperScheduledLives(Map<String, dynamic> helperScheduledLives) async {

    return await allScheduledLives.doc(uid).set
    (
        helperScheduledLives
    );

  }

  Future updateUserReservationTasks() async {

    Map scheduledSpot = {};

    Map dailyTasks = {
      '00':scheduledSpot,
      '1':scheduledSpot,
      '2':scheduledSpot,
      '3':scheduledSpot,
      '4':scheduledSpot,
      '5':scheduledSpot,
      '6':scheduledSpot,
      '7':scheduledSpot,
      '8':scheduledSpot,
      '9':scheduledSpot,
      '10':scheduledSpot,
      '11':scheduledSpot,
      '12':scheduledSpot,
      '13':scheduledSpot,
      '14':scheduledSpot,
      '15':scheduledSpot,
      '16':scheduledSpot,
      '17':scheduledSpot,
      '18':scheduledSpot,
      '19':scheduledSpot,
      '20':scheduledSpot,
      '21':scheduledSpot,
      '22':scheduledSpot,
      '23':scheduledSpot,
    };

    Map<String,dynamic> userReservationTasks ={
      'Monday':dailyTasks,
      'Tuesday':dailyTasks,
      'Wednesday':dailyTasks,
      'Thursday':dailyTasks,
      'Friday':dailyTasks,
      'Saturday':dailyTasks,
      'Sunday':dailyTasks,
    };

    return await allClientsReservationTasks.doc(uid).set
      (
        userReservationTasks
    );

  }

  Future toto(Map<String, dynamic> helperScheduledLives) async {

    var mama = await FirebaseFirestore.instance.collection("allUsers").get();
    mama.docs.asMap();
    return await allScheduledLives.doc(uid).set
      (
        helperScheduledLives
    );

  }

}
