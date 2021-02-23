// Copyright (c) 2014-2019, The Monero Project
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
// 
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import QtQuick 2.9
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import moneroComponents.Clipboard 1.0
import moneroComponents.PendingTransaction 1.0
import moneroComponents.Wallet 1.0
import moneroComponents.NetworkType 1.0
import FontAwesome 1.0
import "../components"
import "../components" as MoneroComponents
import "." 1.0
import "../js/TxUtils.js" as TxUtils
import "../js/Utils.js" as Utils


Rectangle {
    id: root
    signal paymentWClicked(string address, string amount, int mixinCount,
                          int priority, string description)

    color: "transparent"
    property alias transferHeight1: pageRoot.height
    property int mixin: 10  // (ring size 11)
    property string warningContent: ""
    property string sendButtonWarning: {
        // Currently opened wallet is not view-only
        if (appWindow.viewOnly) {
            return qsTr("Wallet is view-only and sends are only possible by using offline transaction signing. " +
                        "Unless key images are imported, the balance reflects only incoming but not outgoing transactions.") + translationManager.emptyString;
        }

        // There are sufficient unlocked funds available
        if (walletManager.amountFromString(amountLine.text) > appWindow.getUnlockedBalance()) {
            return qsTr("Amount is more than unlocked balance.") + translationManager.emptyString;
        }

        if (addressLine.text)
        {
            // Address is valid
            if (!TxUtils.checkEthAddress(addressLine.text)) {
                return qsTr("Address is invalid.") + translationManager.emptyString;
            }

            // Amount is nonzero
            if (!amountLine.text || parseFloat(amountLine.text) <= 0) {
                return qsTr("Enter an amount.") + translationManager.emptyString;
            }
        }

        return "";
    }
    property string startLinkText: "<style type='text/css'>a {text-decoration: none; color: #00abff; font-size: 14px;}</style><a href='#'>(%1)</a>".arg(qsTr("Start daemon")) + translationManager.emptyString
    property bool warningLongPidDescription: descriptionLine.text.match(/^[0-9a-f]{64}$/i)

    Clipboard { id: clipboard }

    function oa_message(text) {
      oaPopup.title = qsTr("OpenAlias error") + translationManager.emptyString
      oaPopup.text = text
      oaPopup.icon = StandardIcon.Information
      oaPopup.onCloseCallback = null
      oaPopup.open()
    }

    function updateFromQrCode(address, payment_id, amount, tx_description, recipient_name) {
        console.log("updateFromQrCode")
        addressLine.text = address
        setPaymentId(payment_id);
        amountLine.text = amount
        setDescription(recipient_name + " " + tx_description);
        cameraUi.qrcode_decoded.disconnect(updateFromQrCode)
    }

    function setDescription(value) {
        descriptionLine.text = value;
        descriptionCheckbox.checked = descriptionLine.text != "";
    }

    function setPaymentId(value) {
        paymentIdLine.text = value;
        paymentIdCheckbox.checked = paymentIdLine.text != "";
    }

    function clearFields() {
        addressLine.text = ""
        setPaymentId("");
        amountLine.text = ""
        setDescription("");
        priorityDropdown.currentIndex = 0
    }

    // Information dialog
    StandardDialog {
        // dynamically change onclose handler
        property var onCloseCallback
        id: oaPopup
        cancelVisible: false
        onAccepted:  {
            if (onCloseCallback) {
                onCloseCallback()
            }
        }
    }

    ColumnLayout {
      id: pageRoot
      anchors.margins: 20
      anchors.topMargin: 40

      anchors.left: parent.left
      anchors.top: parent.top
      anchors.right: parent.right

      spacing: 30

      RowLayout {
          visible: root.warningContent !== ""

          MoneroComponents.WarningBox {
              text: warningContent
              onLinkActivated: {
                  appWindow.startDaemon(appWindow.persistentSettings.daemonFlags);
              }
          }
      }

      RowLayout {
          visible: leftPanel.minutesToUnlock !== ""

          MoneroComponents.WarningBox {
              text: qsTr("Spendable funds: %1 TUBE. Please wait ~%2 minutes for your whole balance to become spendable.").arg(leftPanel.balanceUnlockedString).arg(leftPanel.minutesToUnlock)
          }
      }

      // recipient address input
      RowLayout {
          id: addressLineRow
          Layout.fillWidth: true

          LineEditMulti {
              id: addressLine
              spacing: 0
              inputPaddingRight: inlineButton2Visible ? 100 : 60
              fontBold: true
              labelText: qsTr("ETH Address") + translationManager.emptyString
              labelButtonText: qsTr("Resolve") + translationManager.emptyString
              placeholderText: {
                   return "0x..";
              }
              wrapMode: Text.WrapAnywhere
              ethAddressValidation: true
              onTextChanged: {
                  const parsed = walletManager.parse_uri_to_object(text);
                  if (!parsed.error) {
                    addressLine.text = parsed.address;
                    setPaymentId(parsed.payment_id);
                    amountLine.text = parsed.amount;
                    setDescription(parsed.tx_description);
                  }
              }
              
              inlineButton2.text: FontAwesome.qrcode
              inlineButton2.buttonHeight: 30
              inlineButton2.fontPixelSize: 22
              inlineButton2.fontFamily: FontAwesome.fontFamily
              inlineButton2.textColor: MoneroComponents.Style.defaultFontColor
              inlineButton2.onClicked: {
                   cameraUi.state = "Capture"
                   cameraUi.qrcode_decoded.connect(updateFromQrCode)
              }
              inlineButton2Visible: appWindow.qrScannerEnabled
          }
      }

      StandardButton {
          id: resolveButton
          width: 80
          text: qsTr("Resolve") + translationManager.emptyString
          visible: TxUtils.isValidOpenAliasAddress(addressLine.text)
          enabled : visible
          onClicked: {
              var result = walletManager.resolveOpenAlias(addressLine.text)
              if (result) {
                  var parts = result.split("|")
                  if (parts.length == 2) {
                      var address_ok = walletManager.addressValid(parts[1], appWindow.persistentSettings.nettype)
                      if (parts[0] === "true") {
                          if (address_ok) {
                              // prepend openalias to description
                              descriptionLine.text = descriptionLine.text ? addressLine.text + " " + descriptionLine.text : addressLine.text
                              descriptionCheckbox.checked = true
                              addressLine.text = parts[1]
                          }
                          else
                              oa_message(qsTr("No valid address found at this OpenAlias address"))
                      }
                      else if (parts[0] === "false") {
                            if (address_ok) {
                                addressLine.text = parts[1]
                                oa_message(qsTr("Address found, but the DNSSEC signatures could not be verified, so this address may be spoofed"))
                            }
                            else
                            {
                                oa_message(qsTr("No valid address found at this OpenAlias address, but the DNSSEC signatures could not be verified, so this may be spoofed"))
                            }
                      }
                      else {
                          oa_message(qsTr("Internal error"))
                      }
                  }
                  else {
                      oa_message(qsTr("Internal error"))
                  }
              }
              else {
                  oa_message(qsTr("No address found"))
              }
          }
      }

      GridLayout {
          columns: appWindow.walletMode < 2 ? 1 : 2
          Layout.fillWidth: true
          columnSpacing: 32

          ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 200

              // Amount input
              LineEdit {
                  id: amountLine
                  Layout.fillWidth: true
                  inlineIcon: true
                  labelText: "<style type='text/css'>a {text-decoration: none; color: #858585; font-size: 14px;}</style>\
                                   %1 <a href='#'>(%2)</a>".arg(qsTr("Amount")).arg(qsTr("Change account"))
                             + translationManager.emptyString
                  copyButton: !isNaN(amountLine.text) && persistentSettings.fiatPriceEnabled
                  copyButtonText: "~%1 %2".arg(fiatApiConvertToFiat(amountLine.text)).arg(fiatApiCurrencySymbol())
                  copyButtonEnabled: false

                  onLabelLinkActivated: {
                      middlePanel.accountView.selectAndSend = true;
                      appWindow.showPageRequest("Account")
                  }
                  placeholderText: "0.00"
                  width: 100
                  fontBold: true
                  onTextChanged: {
                        const match = amountLine.text.match(/^0+(\d.*)/);
                        if (match) {
                            const cursorPosition = amountLine.cursorPosition;
                            amountLine.text = match[1];
                            amountLine.cursorPosition = Math.max(cursorPosition, 1) - 1;
                        } else if(amountLine.text.indexOf('.') === 0){
                            amountLine.text = '0' + amountLine.text;
                            if (amountLine.text.length > 2) {
                                amountLine.cursorPosition = 1;
                            }
                        }
                        amountLine.error = walletManager.amountFromString(amountLine.text) > appWindow.getUnlockedBalance()
                  }

                  validator: RegExpValidator {
                      regExp: /^(\d{1,8})?([\.]\d{1,12})?$/
                  }
              }

                MoneroComponents.TextPlain {
                    id: feeLabel
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: 12
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 14
                    color: MoneroComponents.Style.defaultFontColor
                    property bool estimating: false
                    property var estimatedFee: null
                    property string estimatedFeeFiat: {
                        if (!persistentSettings.fiatPriceEnabled || estimatedFee == null) {
                            return "";
                        }
                        const fiatFee = fiatApiConvertToFiat(estimatedFee);
                        return " (%1 %3)".arg(fiatFee < 0.01 ? "<0.01" : "~" + fiatFee).arg(fiatApiCurrencySymbol());
                    }
                    property var fee: {
                        estimatedFee = null;
                        estimating = sendButton.enabled;
                        if (!sendButton.enabled || !currentWallet) {
                            return;
                        }
                        currentWallet.estimateTransactionFeeAsync(
                            addressLine.text,
                            walletManager.amountFromString(amountLine.text),
                            priorityModelV5.get(priorityDropdown.currentIndex).priority,
                            function (amount) {
                                estimatedFee = Utils.removeTrailingZeros(amount);
                                estimating = false;
                            });
                    }
                    text: {
                        if (!sendButton.enabled || estimatedFee == null) {
                            return ""
                        }
                        return "%1: ~%2 TUBE".arg(qsTr("Fee")).arg(estimatedFee) +
                            estimatedFeeFiat +
                            translationManager.emptyString;
                    }

                    BusyIndicator {
                        anchors.right: parent.right
                        running: feeLabel.estimating
                        height: parent.height
                    }
                }
          }

          ColumnLayout {
              visible: appWindow.walletMode >= 2
              Layout.alignment: Qt.AlignTop
              Label {
                  id: transactionPriority
                  Layout.topMargin: 0
                  text: qsTr("Transaction priority") + translationManager.emptyString
                  fontBold: false
                  fontSize: 16
              }
              // Note: workaround for translations in listElements
              // ListElement: cannot use script for property value, so
              // code like this wont work:
              // ListElement { column1: qsTr("LOW") + translationManager.emptyString ; column2: ""; priority: PendingTransaction.Priority_Low }
              // For translations to work, the strings need to be listed in
              // the file components/StandardDropdown.qml too.

              // Priorites after v5
              ListModel {
                   id: priorityModelV5

                   ListElement { column1: qsTr("Automatic") ; column2: ""; priority: 0}
                   ListElement { column1: qsTr("Slow (x0.2 fee)") ; column2: ""; priority: 1}
                   ListElement { column1: qsTr("Normal (x1 fee)") ; column2: ""; priority: 2 }
                   ListElement { column1: qsTr("Fast (x5 fee)") ; column2: ""; priority: 3 }
                   ListElement { column1: qsTr("Fastest (x200 fee)")  ; column2: "";  priority: 4 }
               }

              StandardDropdown {
                  Layout.preferredWidth: 200
                  id: priorityDropdown
                  Layout.topMargin: 5
                  currentIndex: 0
                  dataModel: priorityModelV5
              }
          }
      }

      MoneroComponents.WarningBox {
          text: qsTr("Description field contents match long payment ID format. \
          Please don't paste long payment ID into description field, your funds might be lost.") + translationManager.emptyString;
          visible: warningLongPidDescription
      }

      ColumnLayout {
          spacing: 15

          ColumnLayout {
              CheckBox {
                  id: descriptionCheckbox
                  border: false
                  checkedIcon: FontAwesome.minusCircle
                  uncheckedIcon: FontAwesome.plusCircle
                  fontAwesomeIcons: true
                  fontSize: descriptionLine.labelFontSize
                  iconOnTheLeft: true
                  Layout.fillWidth: true
                  text: qsTr("Add description") + translationManager.emptyString
                  onClicked: {
                      if (!descriptionCheckbox.checked) {
                        descriptionLine.text = "";
                      }
                  }
              }

              LineEditMulti {
                  id: descriptionLine
                  placeholderText: qsTr("Saved to local wallet history") + translationManager.emptyString
                  Layout.fillWidth: true
                  visible: descriptionCheckbox.checked
              }
          }

          ColumnLayout {
              visible: paymentIdCheckbox.checked
              CheckBox {
                  id: paymentIdCheckbox
                  border: false
                    checkedIcon: FontAwesome.minusCircle
                    uncheckedIcon: FontAwesome.plusCircle
                    fontAwesomeIcons: true
                  fontSize: paymentIdLine.labelFontSize
                  iconOnTheLeft: true
                  Layout.fillWidth: true
                  text: qsTr("Add payment ID") + translationManager.emptyString
                  onClicked: {
                      if (!paymentIdCheckbox.checked) {
                        paymentIdLine.text = "";
                      }
                  }
              }

              // payment id input
              LineEditMulti {
                  id: paymentIdLine
                  fontBold: true
                  placeholderText: qsTr("64 hexadecimal characters") + translationManager.emptyString
                  readOnly: true
                  Layout.fillWidth: true
                  wrapMode: Text.WrapAnywhere
                  addressValidation: false
                  visible: paymentIdCheckbox.checked
                  error: paymentIdCheckbox.checked
              }
          }
      }

      MoneroComponents.WarningBox {
          id: paymentIdWarningBox
          text: qsTr("Long payment IDs are obsolete. \
          Long payment IDs were not encrypted on the blockchain and would harm your privacy. \
          If the party you're sending to still requires a long payment ID, please notify them.") + translationManager.emptyString;
          visible: paymentIdCheckbox.checked || warningLongPidDescription
      }

      MoneroComponents.WarningBox {
          id: sendButtonWarningBox
          text: root.sendButtonWarning
          visible: root.sendButtonWarning !== ""
      }

      RowLayout {
          StandardButton {
              id: sendButton
              rightIcon: "qrc:///images/rightArrow.png"
              rightIconInactive: "qrc:///images/rightArrowInactive.png"
              Layout.topMargin: 4
              text: qsTr("Swap to WTUBE") + translationManager.emptyString
              enabled: !sendButtonWarningBox.visible && !warningContent && addressLine.text && !paymentIdWarningBox.visible
              onClicked: {
                  console.log("TransferW: paymentWClicked")
                  var priority = priorityModelV5.get(priorityDropdown.currentIndex).priority
                  console.log("priority: " + priority)
                  console.log("amount: " + amountLine.text)
                  addressLine.text = addressLine.text.trim()
                  root.paymentWClicked(addressLine.text, amountLine.text, root.mixin, priority, descriptionLine.text)
              }
          }
      }

      function checkInformation(amount, address, nettype) {
        return amount.length > 0 && walletManager.amountFromString(amountLine.text) <= appWindow.getUnlockedBalance() && TxUtils.checkEthAddress(address)
      }

    } // pageRoot

    Component.onCompleted: {
        //Disable password page until enabled by updateStatus
        pageRoot.enabled = false
    }

    // fires on every page load
    function onPageCompleted() {
        console.log("transferW page loaded")
        updateStatus();
    }

    //TODO: Add daemon sync status
    //TODO: enable send page when we're connected and daemon is synced

    function updateStatus() {
        var messageNotConnected = qsTr("Wallet is not connected to daemon.");
        if(appWindow.walletMode >= 2 && !persistentSettings.useRemoteNode) messageNotConnected += root.startLinkText;
        pageRoot.enabled = true;
        if(typeof currentWallet === "undefined") {
            root.warningContent = messageNotConnected;
            return;
        }

        if (currentWallet.viewOnly) {
           // warningText.text = qsTr("Wallet is view only.")
           //return;
        }
        //pageRoot.enabled = false;

        switch (currentWallet.connected()) {
        case Wallet.ConnectionStatus_Connecting:
            root.warningContent = qsTr("Wallet is connecting to daemon.")
            break
        case Wallet.ConnectionStatus_Disconnected:
            root.warningContent = messageNotConnected;
            break
        case Wallet.ConnectionStatus_WrongVersion:
            root.warningContent = qsTr("Connected daemon is not compatible with GUI. \n" +
                                   "Please upgrade or connect to another daemon")
            break
        default:
            if(!appWindow.daemonSynced){
                root.warningContent = qsTr("Waiting on daemon synchronization to finish.")
            } else {
                // everything OK, enable transferW page
                // Light wallet is always ready
                pageRoot.enabled = true;
                root.warningContent = "";
            }
        }
    }

    // Popuplate fields from addressbook.
    function sendTo(address, paymentId, description, amount){
        middlePanel.state = 'TransferW';

        if(typeof address !== 'undefined')
            addressLine.text = address

        if(typeof paymentId !== 'undefined')
            setPaymentId(paymentId);

        if(typeof description !== 'undefined')
            setDescription(description);

        if(typeof amount !== 'undefined')
            amountLine.text = amount;
    }
}