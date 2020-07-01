/*
 MIT License

 Copyright (c) 2017-2019 MessageKit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import UIKit
import MapKit
import MessageKit
import InputBarAccessoryView

final class ChatRoomViewController: ChatViewController {

  override func configureMessageCollectionView() {
    super.configureMessageCollectionView()

    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
  }

  override func configureMessageInputBar() {
    super.configureMessageInputBar()

    messageInputBar.separatorLine.isHidden = true
    messageInputBar.inputTextView.tintColor = .primaryColor
    messageInputBar.inputTextView.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
    messageInputBar.inputTextView.placeholderTextColor = .white
    messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 36)
    messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 36)
    messageInputBar.inputTextView.layer.borderColor = UIColor.white.cgColor

    //메세지 입력창 설정
    messageInputBar.inputTextView.keyboardType = .twitter

    messageInputBar.inputTextView.textColor = .white
    messageInputBar.inputTextView.backgroundColor = .clear
    messageInputBar.inputTextView.layer.borderWidth = 1.0
    messageInputBar.inputTextView.layer.cornerRadius = 20.0
    messageInputBar.inputTextView.layer.masksToBounds = true
    messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    configureInputBarItems()
  }

  private func configureInputBarItems() {
    messageInputBar.setRightStackViewWidthConstant(to: 110, animated: false) // stackView 사이즈 마진
    messageInputBar.sendButton.imageView?.backgroundColor = UIColor(white: 0.85, alpha: 1)
    messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
    messageInputBar.sendButton.setSize(CGSize(width: 36, height: 36), animated: false)
    messageInputBar.sendButton.image = #imageLiteral(resourceName: "ic_up")
    messageInputBar.sendButton.title = nil
    messageInputBar.sendButton.imageView?.layer.cornerRadius = 16

    let rightItems = [messageInputBar.sendButton, makeButton(named: "ic_at"), makeButton(named: "ic_hashtag"), .flexibleSpace]
    messageInputBar.setStackViewItems(rightItems, forStack: .right, animated: false)

    let charCountButton = InputBarButtonItem()
      .configure {
        $0.title = "0/140"
        $0.contentHorizontalAlignment = .right
        $0.setTitleColor(UIColor(white: 0.6, alpha: 1), for: .normal)
        $0.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        $0.setSize(CGSize(width: 50, height: 25), animated: false)
      }.onTextViewDidChange { (item, textView) in
      item.title = "\(textView.text.count)/140"
      let isOverLimit = textView.text.count > 140
      item.inputBarAccessoryView?.shouldManageSendButtonEnabledState = !isOverLimit // Disable automated management when over limit
      if isOverLimit {
        item.inputBarAccessoryView?.sendButton.isEnabled = false
      }
      let color = isOverLimit ? .red : UIColor(white: 0.6, alpha: 1)
      item.setTitleColor(color, for: .normal)
      }
    let bottomItems = [.flexibleSpace, charCountButton]

    configureInputBarPadding()

    messageInputBar.setStackViewItems(bottomItems, forStack: .bottom, animated: false)

    messageInputBar.setLeftStackViewWidthConstant(to: 52, animated: false)

    let leftItems = [makeButton(named: "ic_at"), makeButton(named: "ic_hashtag"), .flexibleSpace]
    messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

    // This just adds some more flare
    messageInputBar.sendButton
      .onEnabled { item in
        UIView.animate(withDuration: 0.3, animations: {
          item.imageView?.backgroundColor = .primaryColor
        })
      }.onDisabled { item in
      UIView.animate(withDuration: 0.3, animations: {
        item.imageView?.backgroundColor = UIColor(white: 0.85, alpha: 1)
      })
      }
  }

  /// The input bar will autosize based on the contained text, but we can add padding to adjust the height or width if neccesary
  /// See the InputBar diagram here to visualize how each of these would take effect:
  /// https://raw.githubusercontent.com/MessageKit/MessageKit/master/Assets/InputBarAccessoryViewLayout.png
  private func configureInputBarPadding() {

    // Entire InputBar padding
    messageInputBar.padding.bottom = 8

    // or MiddleContentView padding
    messageInputBar.middleContentViewPadding.right = -38//-38

    // or InputTextView padding
    messageInputBar.inputTextView.textContainerInset.bottom = 8
  }

  func setAvatarData(sender: SenderType) -> Avatar {
    let firstName = sender.displayName.components(separatedBy: " ").first
    let lastName = sender.displayName.components(separatedBy: " ").first
    let initials = "\(firstName?.first ?? "A")\(lastName?.first ?? "A")"
    switch sender.senderId {
    case "000000":
      return Avatar(image: #imageLiteral(resourceName: "Inpyo"), initials: initials)

    default:
      return Avatar(image: #imageLiteral(resourceName: "mj"), initials: initials)
    }
  }

  private func makeButton(named: String) -> InputBarButtonItem {
    return InputBarButtonItem()
      .configure {
        $0.spacing = .fixed(10)
        $0.image = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
        $0.setSize(CGSize(width: 25, height: 25), animated: false)
        $0.tintColor = UIColor(white: 0.8, alpha: 1)
      }.onSelected {
      $0.tintColor = .primaryColor
      }.onDeselected {
      $0.tintColor = UIColor(white: 0.8, alpha: 1)
      }.onTouchUpInside { _ in
      print("Item Tapped")
      }
  }
}

// MARK: - MessagesDisplayDelegate

extension ChatRoomViewController: MessagesDisplayDelegate {
  // MARK: - Text Messages

  func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
    return .white// isFromCurrentSender(message: message) ? .white : .darkText
  }

  // MARK: - All Messages
  func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
    return .clear //isFromCurrentSender(message: message) ? .primaryColor : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
  }

  func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    let avatar = self.setAvatarData(sender: message.sender)
    avatarView.set(avatar: avatar)

    switch message.sender.senderId {
    case "000000":
      avatarView.layer.borderWidth = 2
      avatarView.layer.borderColor = UIColor.primaryColor.cgColor

    default:
      break
    }

  }
}

// MARK: - MessagesLayoutDelegate

extension ChatRoomViewController: MessagesLayoutDelegate {
  func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 0//18
  }

  func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 0
  }

  func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 16
  }

  func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    return 0 //16
  }
}