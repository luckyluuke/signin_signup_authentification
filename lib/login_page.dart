import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signin_signup_authentification/delayed_animation.dart';
import 'package:signin_signup_authentification/flying_dots_animation.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:signin_signup_authentification/UserManager.dart';
import 'package:signin_signup_authentification/database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signin_signup_authentification/enums.dart';
import 'package:public_ip_address/public_ip_address.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pseudoController = TextEditingController();
final _phoneController = TextEditingController();
//final _codeController = TextEditingController();
final _emailController = TextEditingController();
final _passwordController = TextEditingController();

String dialCodeDigits ="";


class LoginPage extends StatefulWidget {

  final String ipReal;
  final String countryCodeReal;

  LoginPage(this.ipReal,this.countryCodeReal);

  @override
  _LoginPageState createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage> {

  bool isLoading = false;
  bool appIsInMaintenance = false;
  int? totalFreeCoins;
  bool isCheckingCode = false;
  int registrationMode = 0;
  bool firstNavigationTriggered = false;

  DocumentReference ? _allBasicDataRef;
  StreamSubscription ? _subscriptionAllBasicData;

  void triggerAlertMessage(String message, BuildContext context){
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            actions: [
              Text(message, style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 15,
              ) ,),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Fermer")),
            ],
          );
        }
    );
  }

  @override
  void initState(){
    super.initState();
    _allBasicDataRef = FirebaseFirestore.instance.collection('allBasicData').doc("forAllUsers");
    _subscriptionAllBasicData = _allBasicDataRef!.snapshots().listen( (snapshot){
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      if (data != null){
        if (this.mounted){
          totalFreeCoins = data['freeCoins'];
          appIsInMaintenance = data['appIsInMaintenance'];
        }
      }
    });
  }

  @override
  void dispose(){
    super.dispose();
    _subscriptionAllBasicData!.cancel();
  }

  Future<User?> registerUsingEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;
    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;
      await user!.updateDisplayName(name);
      await user.reload();
      user = auth.currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.')));
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce compte existe déjà.')));
      }else if (e.code == 'invalid-email') {
        print('The email is invalid');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ton email est invalide.')));
      }else if (e.code == 'operation-not-allowed') {
        print('ERROR: The account creation permission denied.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ton pseudo ou ton email n\'est pas correct.")));
    }
    return user;
  }

  Future<User?> signUsingEmailPassword({
    required String email,
    required String password,
  }) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;
      await user!.reload();
      user = auth.currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        print('The password provided is incorrect.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le mot de passe est incorrect.')));
      } else if (e.code == 'user-disabled') {
        print('The account has been blocked.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce compte a été bloqué.')));
      }else if (e.code == 'invalid-email') {
        print('The email is invalid');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ton email est invalide.')));
      }else if (e.code == 'user-not-found') {
        print('Aucun compte ne correspond à l\'email fourni.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun compte ne correspond à l\'email fourni.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ton email ou ton mot de passe est pas incorrect.")));
    }
    return user;
  }

  createNewUser(String pseudo, String email, String password,changeStateButton) async {
    if (pseudo.isNotEmpty)
    {
      if (email.isNotEmpty) {
        if(password.isNotEmpty){
          HttpsCallable callable = await FirebaseFunctions.instanceFor(app: FirebaseFunctions.instance.app, region: "europe-west1").httpsCallable("getResultWhere");
          var result = await callable.call(
              {
                'limit':1,
                'collectionName':'allUsers',
                'comparedField':'pseudo',
                'comparisonSign': '==',
                'toValue':pseudo
              }
          );

          final pseudoExists = (result.data == null ? false : true);

          bool isCountryValid = (g_countriesCurrenciesRates.keys.contains(widget.countryCodeReal) ? true : false);

          if(isCountryValid){
            if (!pseudoExists)
            {

              final prefs = await SharedPreferences.getInstance();

              var currentUser = await registerUsingEmailPassword(name:pseudo ,email: email,password: password);

              if (currentUser != null) {

                UserManager _userManager = UserManager();

                bool userExists = await _userManager.checkIfDocExists("allUsers", currentUser.uid);
                if (false == userExists){
                  int coinsToGive = 0;
                  int finalThreshold = totalFreeCoins! - 600;
                  if (finalThreshold >= 0){
                    coinsToGive = 600;

                    Map paramsToBeUpdated = {
                      "freeCoins": {
                        "mode": "increment",
                        "value": -coinsToGive
                      }
                    };

                    Map parametersUpdated = {
                      "advancedMode":true,
                      "docId":"forAllUsers",
                      "collectionName":"allBasicData",
                      "paramsToBeUpdated": json.encode(paramsToBeUpdated),
                    };

                    await _userManager.callCloudFunction("updateUserInfo", parametersUpdated);
                  }

                  DatabaseService db = DatabaseService(currentUser.uid);

                  await db.updateUserData(pseudo , email/*dialCodeDigits + phone*//*currentUser.phoneNumber*/, coinsToGive, widget.countryCodeReal, appIsInMaintenance);
                  await db.updateUserFees();
                  await db.updateUserSubscriptionsAndSubscribers();
                  await db.updateUserHelperScheduledLives(g_daysScheduledLives);
                  await db.updateUserReservationTasks();

                }
                else
                {
                  String? token_id = await FirebaseMessaging.instance.getToken();
                  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
                  String? voipToken = await prefs.getString("voipToken");

                  await _userManager.updateMultipleValues(
                      "allUsers",
                      {
                        'token_firebasemsg_id': token_id,
                        'apnsToken':apnsToken,
                        'isAppTerminated':false,
                        'isIOS':Platform.isIOS,
                        'voipToken':voipToken,
                        'appIsInMaintenance':appIsInMaintenance
                      }
                  );

                  bool isHelper = await _userManager.getValue("allUsers", "is_helper");
                  if (isHelper){
                    _userManager.updateMultipleValues(
                        "allHelpers",
                        {
                          'token_firebasemsg_id': token_id,
                          'isUserActive':true,
                        }
                    );
                  }
                }

                /*Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (context) => HomePage(),
                ));*/

              }else{
                changeStateButton(() {
                  isLoading = false;
                });
              }

            }
            else {
              changeStateButton(() {
                isLoading = false;
              });
              triggerAlertMessage("Ce pseudo existe déjà. Crées-en un autre !", context);
            }
          }else{
            changeStateButton(() {
              isLoading = false;
            });
            triggerAlertMessage("L'application n'est pas disponible dans le pays selectionné.", context);
          }

        }else{
          changeStateButton(() {
            isLoading = false;
          });
          triggerAlertMessage("Il manque ton mot de passe.", context);
        }

      }
      else
      {
        changeStateButton(() {
          isLoading = false;
        });
        triggerAlertMessage("Il manque ton adresse mail.", context);
      }
    }
    else{
      changeStateButton(() {
        isLoading = false;
      });
      triggerAlertMessage("Tu n'a pas saisi de pseudo.", context);
    }
  }

  loginWithEmailAndPassword(String email, String password,changeStateButton) async {
    if(email.isNotEmpty){
      if(password.isNotEmpty){
        var currentUser = await signUsingEmailPassword(email:email,password: password);
        if (currentUser != null){
            UserManager _userManager = UserManager();
            final prefs = await SharedPreferences.getInstance();

            String? token_id = await FirebaseMessaging.instance.getToken();
            String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            String? voipToken = await prefs.getString("voipToken");

            await _userManager.updateMultipleValues(
                "allUsers",
                {
                  'token_firebasemsg_id': token_id,
                  'apnsToken':apnsToken,
                  'isAppTerminated':false,
                  'isIOS':Platform.isIOS,
                  'voipToken':voipToken,
                  'appIsInMaintenance':appIsInMaintenance
                }
            );

            bool isHelper = await _userManager.getValue("allUsers", "is_helper");
            if (isHelper){
              _userManager.updateMultipleValues(
                  "allHelpers",
                  {
                    'token_firebasemsg_id': token_id,
                    'isUserActive':true,
                  }
              );
            }

            /*Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => HomePage(),
            ));*/

          }else{
            changeStateButton(() {
              isLoading = false;
            });
          }

        }else{
          changeStateButton(() {
            isLoading = false;
          });
          triggerAlertMessage("Il manque ton mot de passe.", context);
        }
      }else{
        changeStateButton(() {
          isLoading = false;
        });
        triggerAlertMessage("Il manque ton adresse mail.", context);
      }
  }

  loginWithPhoneNumber(String phone,changeStateButton) async {
    if(phone.isNotEmpty){
      HttpsCallable registrationCallable = await FirebaseFunctions.instanceFor(app: FirebaseFunctions.instance.app, region: "europe-west1").httpsCallable("createNewUserRegistration");
      var resultRegistration = await registrationCallable.call(
        {
          "phone": dialCodeDigits /*codes.where((element) => element["code"] == widget.countryCodeReal).first["dial_code"]!*/ + phone.trim().replaceAll(RegExp("[ \n\t\r\f]"), '')
        }
      );

      final registrationStatus = resultRegistration.data["status"];

      if(registrationStatus == "success"){
        FirebaseAuth _auth = FirebaseAuth.instance;
        UserCredential result = await _auth.signInWithCustomToken(resultRegistration.data["customToken"]);
        User? currentUser = result.user;
        if (currentUser != null) {
          UserManager _userManager = UserManager();
          final prefs = await SharedPreferences.getInstance();

          String? token_id = await FirebaseMessaging.instance.getToken();
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          String? voipToken = await prefs.getString("voipToken");

          bool isHelper = await _userManager.getValue("allUsers", "is_helper");
          if (isHelper){
            _userManager.updateMultipleValues(
                "allHelpers",
                {
                  'token_firebasemsg_id': token_id,
                  'isUserActive':true,
                }
            );
          }

          await _userManager.updateMultipleValues(
              "allUsers",
              {
                'token_firebasemsg_id': token_id,
                'apnsToken':apnsToken,
                'isAppTerminated':false,
                'isIOS':Platform.isIOS,
                'voipToken':voipToken,
                'appIsInMaintenance':appIsInMaintenance
              }
          );

          /*Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => HomePage(),
          ));*/
        }else{
          changeStateButton(() {
            isLoading = false;
          });
          triggerAlertMessage("Ce compte n'existe pas. Tu ne peux pas te connecter avec ce numéro.", context);
        }

      }else{
        changeStateButton(() {
          isLoading = false;
        });
        triggerAlertMessage("Ce compte n\'existe pas. Tu ne peux pas te connecter avec ce numéro.", context);
      }
    }else{
      changeStateButton(() {
        isLoading = false;
      });
      triggerAlertMessage("Il manque ton numéro de téléphone.", context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back ,
            color: Colors.black,
            size: 30,
          ),
          onPressed: () {
            if(registrationMode == 0){
              Navigator.pop(context);
            }else{
              setState(() {

                //dialCodeDigits = codes.where((element) => element["code"] == widget.countryCodeReal).first["dial_code"]!;
                //countryCode = widget.countryCodeReal;

                if(dialCodeDigits != ""){
                  dialCodeDigits = "";
                }

                firstNavigationTriggered = true;
                registrationMode = 0;
              });
            }

            _emailController.text = "";
            _passwordController.text = "";
            _pseudoController.text = "";
            _phoneController.text = "";

          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: DelayedAnimation(
                      delay: 500,
                      child: Text(
                        (registrationMode == 0) ?"Avant de débuter" : "Connexion",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  if(registrationMode == 0)
                  Center(
                    child: DelayedAnimation(
                      delay: !firstNavigationTriggered ? 1000 : 0,
                      child: Text(
                        "Crée un compte en moins de 5 secondes !",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if(registrationMode == 0)
            SizedBox(height: 35),
            LoginForm(registrationMode,(authMode){
              setState(() {
                registrationMode = authMode;
              });
            },
            firstNavigationTriggered,
              widget.ipReal,
              widget.countryCodeReal,
            ),
            SizedBox(height: 50),
            DelayedAnimation(
              delay: !firstNavigationTriggered ? 1000 : 0,
              child: StatefulBuilder(
                builder: (context, changeStateButton) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: StadiumBorder(),
                      primary: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 125,
                        vertical: 13,
                      ),
                    ),
                    child: isLoading ?
                    TwoFlyingDots(dotsSize: 30, firstColor: Colors.blue, secondColor: Colors.yellow)
                        :
                    Text(
                    (registrationMode == 0) ? 'VALIDER' : 'SE CONNECTER',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () async {
                      changeStateButton(() {
                        isLoading = true;
                      });

                      final phone = _phoneController.text.trim();
                      final email = _emailController.text.trim().replaceAll(RegExp("[ \n\t\r\f]"), '');
                      final password = _passwordController.text.trim();
                      final pseudo = _pseudoController.text.trim().toLowerCase().replaceAll(RegExp("[ \n\t\r\f]"), '');

                      if(registrationMode == 0){
                        createNewUser(pseudo, email, password,changeStateButton);
                      }else if (registrationMode == 1){
                        loginWithEmailAndPassword(email,password,changeStateButton);
                      }else if (registrationMode == 2){
                        loginWithPhoneNumber(phone, changeStateButton);
                      }
                    },
                  );
                }
              ),
            ),
            SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  int? registrationMode;
  final Function(int) onAuthChange;
  bool? firstNavigationTriggered;
  final String ipReal;
  final String countryCodeReal;

  LoginForm(this.registrationMode,this.onAuthChange,this.firstNavigationTriggered,this.ipReal,this.countryCodeReal);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {

  //String dialCodeDigits = "";

  selectAuthMode(){
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)
              ),
              title: Text(
                "Se connecter avec",
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content:
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: (){
                      widget.onAuthChange(1);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10,right: 10),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey,
                                  blurRadius: 4,
                                  offset: Offset(0,3)
                              ),
                            ]
                        ),
                        padding: EdgeInsets.all(10),
                        height: 70,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.email,color: Colors.white),
                            Flexible(
                              child: Text(
                                "Email/Mot de passe",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: (){
                      dialCodeDigits = codes.where((element) => element["code"] == widget.countryCodeReal).first["dial_code"]!;
                      widget.onAuthChange(2);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10,right: 10),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey,
                                  blurRadius: 4,
                                  offset: Offset(0,3)
                              ),
                            ]
                        ),
                        padding: EdgeInsets.all(10),
                        height: 70,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.phone,color: Colors.white),
                            Flexible(
                              child: Text(
                                "Numéro de téléphone",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          }
      );
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 30,
      ),
      child: Column(
        children: [
          if (widget.registrationMode == 0)
          DelayedAnimation(
            delay: !widget.firstNavigationTriggered! ? 1000 : 0,
            child: TextField(
              maxLength: 15,
              decoration: InputDecoration(
                labelText: 'Pseudo (visible par tous)',
                labelStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              controller: _pseudoController,
            ),
          ),
          if (widget.registrationMode == 0)
          SizedBox(height: 30),
          if ((widget.registrationMode == 0) || (widget.registrationMode == 2))
          DelayedAnimation(
            delay: !widget.firstNavigationTriggered! ? 1000 : 0,
            child: Container(
              width: 180,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow,
                border: Border.all(),
                borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey,
                        blurRadius: 4,
                        offset: Offset(0, 3)
                    ),
                  ]
              ),
              child: CountryCodePicker(
                onChanged: (country){
                  setState(() {
                    if(widget.registrationMode == 2){
                      dialCodeDigits = country.dialCode!;
                    }
                  });
                },
                initialSelection: widget.countryCodeReal,
                showCountryOnly: (widget.registrationMode == 0) ? true : false,
                showOnlyCountryWhenClosed: false,
                favorite: [widget.countryCodeReal],
                searchDecoration: InputDecoration(
                  hintText: 'Rechercher',
                  contentPadding: EdgeInsets.all(10),
                ),
                builder: (context) {
                  String? dial = context!.dialCode;
                  String? urlImage = context.flagUri;

                  return Row(
                    mainAxisAlignment: (widget.registrationMode != 0) ?  MainAxisAlignment.spaceAround : MainAxisAlignment.center,
                    children: [
                      Text(
                        "Pays:"
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey[800],
                        size: 40,
                      ),
                      Container(
                        width: 40,
                        height: 50,
                        //color:Colors.red,
                        child: Image.asset(
                            urlImage!,
                          package: 'country_code_picker',
                        ),
                      ),
                      if (widget.registrationMode != 0)
                      Text(dial!)
                    ],
                  );
                }

              ),
            ),

          ),
          if ((widget.registrationMode! == 0) || (widget.registrationMode! == 2))
          SizedBox(height: 13),
          if (widget.registrationMode! < 2)
          DelayedAnimation(
            delay: !widget.firstNavigationTriggered! ? 1000 : 0,
            child: TextField(
              decoration: InputDecoration(
                hintText: "henri@gmail.com",
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic
                ),
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              //keyboardType: TextInputType.number,
              controller: _emailController,
            ),
          ),
          if (widget.registrationMode! < 2)
          SizedBox(height: 13),
          if (widget.registrationMode! < 2)
          DelayedAnimation(
            delay: !widget.firstNavigationTriggered! ? 1000 : 0,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              controller: _passwordController,
            ),
          ),
          if (widget.registrationMode! < 2)
          SizedBox(height: 40),
          if (widget.registrationMode == 0)
          Center(
            child: DelayedAnimation(
              delay: !widget.firstNavigationTriggered! ? 1000 : 0,
              child: InkWell(
                onTap: (){
                  selectAuthMode();
                },
                child: Container(
                  child: Text(
                    "Déjà un compte ?",
                    style: GoogleFonts.inter(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decorationThickness: 2
                    ),
                  ),
                )
              ),
            ),
          ),
          if (widget.registrationMode == 2)
          DelayedAnimation(
            delay: !widget.firstNavigationTriggered! ? 1000 : 0,
            child: TextField(
              decoration: InputDecoration(
                prefix: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(dialCodeDigits.isNotEmpty ? dialCodeDigits : codes.where((element) => element["code"] == widget.countryCodeReal).first["dial_code"]!),
                ),
                labelText: 'Numéro De Téléphone',
                labelStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              keyboardType: TextInputType.number,
              controller: _phoneController,
            ),
          ),
        ],
      ),
    );
  }
}
