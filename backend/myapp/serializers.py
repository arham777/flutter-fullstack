from django.contrib.auth.models import User
from rest_framework import serializers
from .models import Meal

class SignUpSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['username', 'password']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user

class MealSerializer(serializers.ModelSerializer):
    class Meta:
        model = Meal
        fields = ['id', 'title', 'price', 'imageurl', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
