class ProcessedEvent < ApplicationRecord
  validates :event_id,    presence: true
  validates :user_id,     presence: true
  validates :event_type,  presence: true
  validates :occurred_at, presence: true

  scope :for_user,     ->(uid)      { where(user_id: uid) }
  scope :between_days, ->(from, to) { where("occurred_at::date BETWEEN ? AND ?", from, to) }
  scope :on_day,       ->(d)        { where("occurred_at::date = ?", d) }
end
