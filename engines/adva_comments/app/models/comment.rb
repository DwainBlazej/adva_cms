class Comment < ActiveRecord::Base
  class CommentNotAllowed < StandardError; end

  define_callbacks :after_approve, :after_unapprove
  after_save do |comment|
    comment.send :callback, :after_approve   if comment.just_approved?
    comment.send :callback, :after_unapprove if comment.just_unapproved?
  end

  filtered_column :body
  filters_attributes :sanitize => :body_html

  has_filter :text  => { :attributes => [:body] },
             :state => { :states => [:approved, :unapproved] }
  
  belongs_to :site
  belongs_to :section
  belongs_to :commentable, :polymorphic => true
  belongs_to_author
  has_many :activities, :as => :object # move to adva_activity?

  validates_presence_of :body, :commentable

  before_validation :set_owners
  before_create :authorize_commenting

  def owner
    commentable
  end

  def filter
    commentable.comment_filter
  end

  def unapproved?
    !approved?
  end

  def just_approved?
    approved_changed? and approved?
  end

  def just_unapproved?
    approved_changed? and unapproved?
  end

  def state_changes
    state_changes = if just_approved?
      [:approved]
    elsif just_unapproved?
      [:unapproved]
    end || []
    super + state_changes
  end

  def spam_info
    read_attribute(:spam_info) || {}
  end

  has_many :spam_reports, :as => :subject

  def spam_threshold
    51 # TODO have a config option on site for this
  end

  def ham?
    spaminess.to_i < spam_threshold
  end

  def spam?
    spaminess.to_i >= spam_threshold
  end

  def check_approval(context = {})
    if section.respond_to?(:spam_engine)
      section.spam_engine.check_comment(self, context)
      self.spaminess = calculate_spaminess
      self.approved = ham?
      save!
    end
  end

  def calculate_spaminess
    sum = spam_reports(true).inject(0){|sum, report| sum + report.spaminess }
    sum > 0 ? sum / spam_reports.count : 0
  end

  protected

    def authorize_commenting
      if commentable && !commentable.accept_comments?
        raise CommentNotAllowed, I18n.t(:'adva.comments.messages.not_allowed')
      end
    end

    def set_owners
      if commentable # TODO in what cases would commentable be nil here?
        self.site = commentable.site
        self.section = commentable.section
      end
    end
end
