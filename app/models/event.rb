# == Schema Information
#
# Table name: events
#
#  id           :integer          not null, primary key
#  title        :string(255)      not null
#  created_at   :datetime
#  updated_at   :datetime
#  organizer_id :integer
#  published    :boolean          default(FALSE)
#  description  :text
#  started_at   :datetime
#  title_image  :string(255)
#  place        :string(255)
#

class Event < ActiveRecord::Base
  mount_uploader :title_image, EventTitleImageUploader

  belongs_to :organizer, class_name: 'User'

  has_many :event_participations
  has_many :participants, class_name: 'User', through: :event_participations, source: :user

  validates :title, presence: true
  validates :organizer, presence: true
  validates :place, presence: true
  validates :description, presence: true
  validates :started_at, presence: true

  scope :ordered_desc,  -> { order(started_at: :desc) }
  scope :ordered_asc,   -> { order(started_at: :asc) }

  scope :published, -> { where(published: true) }

  scope :past,    -> { ordered_desc.where("started_at < ?", Time.now.beginning_of_day ) }
  scope :future,  -> { ordered_asc.where("started_at >= ?", Time.now.beginning_of_day ) }

  scope :visible_by_user, -> (user) {
    return published if user.nil?
    user.admin? ? all : where("organizer_id = ? OR published = ?", user.id, true)
  }


  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  def slug_candidates
    [[ started_at.strftime("%Y-%m-%d"), title ]]
  end

  def user_participated?(user)
    user && event_participations.find_by(user_id: user.id)
  end

  def participation_for(user)
    event_participations.find_by(user_id: user.id)
  end

  def past?
    started_at < Time.now
  end

  def publish!
    self.published_at = Time.now
    self.toggle :published
    save!
  end

  def cancel_publication!
    self.toggle :published
    save!
  end

  def ics_uid
    "#{created_at.iso8601}-#{started_at.iso8601}-#{id}@#{Figaro.env.mailing_host}"
  end

  def to_ics
    event = Icalendar::Event.new
    event.dtstart = started_at.strftime("%Y%m%dT%H%M%S")
    event.summary = title
    event.description = self.decorate.simple_description
    event.location = place
    event.created = created_at
    event.last_modified = updated_at
    event.uid = ics_uid
    event.url = Rails.application.routes.url_helpers.event_url(self, host: Figaro.env.mailing_host)
    event
  end
end
