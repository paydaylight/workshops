FactoryBot.define do
  factory :email_notification do |f|
    f.format { 'html' }
    f.handler { 'liquid' }
    f.body { Faker::Lorem.paragraph }

    trait :default_invited do
      path { '/default/Invited' }
      default { true }
    end

    trait :eo_invited do
      path { '/EO/Hybrid/5 Day Workshop/Invited' }
      default { false }
    end

    trait :eo_not_yet_invited do
      path { '/EO/Hybrid/5 Day Workshop/Not Yet Invited' }
      default { false }
    end

    trait :default_not_yet_invited do
      path { '/default/Not Yet Invited' }
      default { true }
    end

    trait :default_undecided do
      path { '/default/Undecided' }
      default { true }
    end
  end
end
