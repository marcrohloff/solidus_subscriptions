require 'rails_helper'

RSpec.describe SolidusSubscriptions::Installment, type: :model do
  it { is_expected.to have_many :details }
  it { is_expected.to belong_to :order }
  it { is_expected.to belong_to :subscription }

  it { is_expected.to validate_presence_of :subscription }

  let(:installment) { create :installment }

  describe '#line_item_builder' do
    subject { installment.line_item_builder }

    let(:line_item) { installment.subscription.line_item }

    it { is_expected.to be_a SolidusSubscriptions::LineItemBuilder }
    it { is_expected.to have_attributes(subscription_line_item: line_item) }
  end

  describe '#out_of_stock' do
    subject { installment.out_of_stock }

    let(:expected_date) do
      Date.today + SolidusSubscriptions::Config.reprocessing_interval
    end

    it { is_expected.to be_a SolidusSubscriptions::InstallmentDetail }
    it { is_expected.to_not be_successful }
    it 'has the correct message' do
      expect(subject).to have_attributes(
        message: I18n.t('solidus_subscriptions.installment_details.out_of_stock')
      )
    end

    it 'advances the installment actionable_date' do
      subject
      actionable_date = installment.reload.actionable_date
      expect(actionable_date).to eq expected_date
    end
  end

  describe '#success!' do
    subject { installment.success! }

    let(:installment) { create :installment, actionable_date: actionable_date }
    let(:actionable_date) { 1.month.from_now.to_date }

    it 'removes any actionable date if any' do
      expect { subject }.
        to change { installment.actionable_date }.
        from(actionable_date).to(nil)
    end

    it 'creates a new installment detail' do
      expect { subject }.
        to change { SolidusSubscriptions::InstallmentDetail.count }.
        by(1)
    end

    it 'creates a successful installment detail' do
      subject
      expect(installment.details.last).to be_successful && have_attributes(
        message: I18n.t('solidus_subscriptions.installment_details.success')
      )
    end
  end
end
