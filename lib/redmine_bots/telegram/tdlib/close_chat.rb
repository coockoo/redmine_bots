module RedmineBots::Telegram::Tdlib
  class CloseChat < Command
    def call(chat_id)
      Promises.zip(
        Promises.future { Setting.find_by(name: 'plugin_redmine_bots').value['telegram_bot_id'].to_i },
        client.get_me.then(&:id)
      ).then do |*robot_ids|
        client.get_chat(chat_id).then do |chat|
          client.get_basic_group_full_info(chat.type.basic_group_id)
        end.flat.then do |group_info|
          bot_id, robot_id = robot_ids
          bot_member_ids, regular_member_ids = group_info.members.partition { |m| m.user_id.in?(robot_ids) }.map do |arr|
            arr.map(&:user_id)
          end
          member_ids = (regular_member_ids + (bot_member_ids & [bot_id]) + (bot_member_ids & [robot_id]))
          member_ids.reduce(Promises.fulfilled_future(nil)) do |promise, member_id|
            promise.then { delete_member(chat_id, member_id) }.flat
          end
        end.flat
      end.flat
    end

    private

    def delete_member(chat_id, user_id)
      client.set_chat_member_status(chat_id, user_id, ChatMemberStatus::Left.new)
    end
  end
end
