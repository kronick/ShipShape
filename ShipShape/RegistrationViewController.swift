//
//  RegistrationViewController.swift
//  ShipShape
//
//  Created by Sam Kronick on 6/28/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import UIKit

public enum RegistrationMode: String {
    case Signup
    case Login
    case Facebook
    case Google
    case Forgot
}

class RegistrationViewController: UIViewController, UITextFieldDelegate {

    var mode = RegistrationMode.Signup
    var waiting = false
    var defaultText = "Inspire others with your sailing adventures— once you're logged in, you can make your recorded voyages public and contribute to the Ship Shape global map."
    
    @IBOutlet weak var messageTextLabel: UILabel!
    
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var passwordLabel: UILabel!
    
    @IBOutlet weak var backgroundImage: UIImageView!
    
    
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var modeSwitchButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.dismissKeyboard()
        super.touchesBegan(touches, withEvent: event)
    }

    // MARK: - Form state machine
    func changeMode(nextMode: RegistrationMode) -> Bool{
        var ty = -40 as CGFloat
        switch self.mode {
        case .Signup:
            switch nextMode {
            case .Login:
                // Hide first form field, change button text
                self.messageTextLabel.text = defaultText
                self.goButton.setTitle("Log In", forState: .Normal)
                self.modeSwitchButton.setTitle("Create an account", forState: .Normal)
                self.emailLabel.text = "Username or E-mail"
                UIView.animateWithDuration(0.5, animations: {
                        self.usernameLabel.alpha = 0
                        self.usernameField.alpha = 0
                    
                        self.emailField.transform = CGAffineTransformMakeTranslation(0, ty)
                        self.emailLabel.transform = CGAffineTransformMakeTranslation(0, ty)
                        self.passwordField.transform = CGAffineTransformMakeTranslation(0, ty)
                        self.passwordLabel.transform = CGAffineTransformMakeTranslation(0, ty)
                        self.goButton.transform = CGAffineTransformMakeTranslation(0, ty)
                        self.activityIndicator.transform = CGAffineTransformMakeTranslation(0, ty)
                        
                    }, completion: { complete in
                        self.usernameLabel.hidden = true
                        self.usernameField.hidden = true
                        self.mode = nextMode
                    }
                )
                return true
            default:
                return false
            }
        case .Login:
            switch nextMode {
            case .Signup:
                // Show first form field, change button text
                self.messageTextLabel.text = defaultText
                self.goButton.setTitle("Sign Up", forState: .Normal)
                self.modeSwitchButton.setTitle("Already a user?", forState: .Normal)
                self.emailLabel.text = "E-Mail"
                
                self.usernameLabel.hidden = false
                self.usernameField.hidden = false
                UIView.animateWithDuration(0.5, animations: {
                        self.usernameLabel.alpha = 1
                        self.usernameField.alpha = 1
                    
                        self.emailField.transform = CGAffineTransformMakeTranslation(0, 0)
                        self.emailLabel.transform = CGAffineTransformMakeTranslation(0, 0)
                        self.passwordField.transform = CGAffineTransformMakeTranslation(0, 0)
                        self.passwordLabel.transform = CGAffineTransformMakeTranslation(0, 0)
                        self.goButton.transform = CGAffineTransformMakeTranslation(0, 0)
                        self.activityIndicator.transform = CGAffineTransformMakeTranslation(0, 0)
                    }, completion: { complete in
                        self.mode = nextMode
                    }
                )
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        return true
        //self.dismissKeyboard()
        //return false
    }
    
    // MARK: - Interface actions
    
    @IBAction func cancelRegistration(sender: AnyObject) {
        self.performSegueWithIdentifier("DismissRegistration", sender: self)
    }
    
    @IBAction func submit(sender: AnyObject) {
        if self.waiting {
            return
        }
        switch self.mode {
        case .Signup:
            self.waiting = true
            self.activityIndicator.startAnimating()
            let username = self.usernameField.text!
            let email = self.emailField.text!
            let password = self.passwordField.text!
            RemoteAPIManager.sharedInstance.registerSailor(username, email: email, password: password, callback: { (success, response) in
                self.waiting = false
                self.activityIndicator.stopAnimating()
                if success {
                    print(response)
                    
                    self.messageTextLabel.text = "Success!"
                    
                    // Log in via app delegate
                    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    appDelegate.logIn(username, password: password)
                    self.cancelRegistration(self)
                }
                else {
                    
                    self.messageTextLabel.text = "⚠️ " + response["error"].stringValue
                    // Shake animation
                    UIView.animateKeyframesWithDuration(0.5, delay: 0, options: .CalculationModePaced, animations: {
                        UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 1/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(40, 0)
                        })
                        UIView.addKeyframeWithRelativeStartTime(1/4, relativeDuration: 2/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(-40, 0)
                        })
                        UIView.addKeyframeWithRelativeStartTime(3/4, relativeDuration: 1/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(0, 0)
                        })
                        }, completion: nil)
                    
                }
            })
        case .Login:
            self.waiting = true
            self.activityIndicator.startAnimating()
            let username = self.emailField.text!
            let password = self.passwordField.text!
            RemoteAPIManager.sharedInstance.checkAuth(username, password: password, callback: { (success, response) in
                self.waiting = false
                self.activityIndicator.stopAnimating()
                if success {
                    print(response)
                    
                    self.messageTextLabel.text = "Success!"
                    
                    // Log in via app delegate
                    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    appDelegate.logIn(username, password: password)
                    self.cancelRegistration(self)
                }
                else {
                    self.messageTextLabel.text = "⚠️ " + response["error"].stringValue
                    // Shake animation
                    UIView.animateKeyframesWithDuration(0.5, delay: 0, options: .CalculationModePaced, animations: {
                        UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 1/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(40, 0)
                        })
                        UIView.addKeyframeWithRelativeStartTime(1/4, relativeDuration: 2/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(-40, 0)
                        })
                        UIView.addKeyframeWithRelativeStartTime(3/4, relativeDuration: 1/4, animations: {
                            self.messageTextLabel.transform = CGAffineTransformMakeTranslation(0, 0)
                        })
                        }, completion: nil)
                    
                }
            })
        default:
            return
        }
        
    }
    @IBAction func ChangeModeAction(sender: NSObject) {
        if sender == self.modeSwitchButton {
            if mode == .Signup {
                self.changeMode(.Login)
            }
            else {
                self.changeMode(.Signup)
            }
        }
        else if sender == self.forgotPasswordButton {
            self.changeMode(.Forgot)
        }
    }
    @IBAction func dismissKeyboard(sender: AnyObject? = nil) {
        self.view.endEditing(true)
    }

}
