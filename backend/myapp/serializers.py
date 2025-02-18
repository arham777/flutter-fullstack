from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Meal, Review, CartItem

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'is_active']

class SignUpSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(
        required=True,
        error_messages={
            'required': 'Please provide an email address',
            'invalid': 'Please provide a valid email address'
        }
    )
    password = serializers.CharField(
        write_only=True,
        required=True,
        min_length=6,
        error_messages={
            'required': 'Please provide a password',
            'min_length': 'Password must be at least 6 characters long'
        }
    )
    username = serializers.CharField(
        required=True,
        min_length=3,
        error_messages={
            'required': 'Please provide a username',
            'min_length': 'Username must be at least 3 characters long'
        }
    )

    class Meta:
        model = User
        fields = ['username', 'email', 'password']

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists')
        return value

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('This username is already taken')
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user

class ReviewSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    rating = serializers.IntegerField(min_value=1, max_value=5, required=True)
    comment = serializers.CharField(required=True)

    class Meta:
        model = Review
        fields = ['id', 'user', 'username', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'user', 'username', 'created_at']

    def validate_rating(self, value):
        if not 1 <= value <= 5:
            raise serializers.ValidationError('Rating must be between 1 and 5')
        return value

    def validate_comment(self, value):
        if len(value.strip()) == 0:
            raise serializers.ValidationError('Comment cannot be empty')
        return value.strip()

class MealSerializer(serializers.ModelSerializer):
    reviews = ReviewSerializer(many=True, read_only=True)
    average_rating = serializers.SerializerMethodField()
    review_count = serializers.SerializerMethodField()
    title = serializers.CharField(required=True)
    price = serializers.DecimalField(max_digits=10, decimal_places=2, required=True)
    imageurl = serializers.URLField(required=True)

    class Meta:
        model = Meal
        fields = ['id', 'title', 'price', 'imageurl', 'reviews', 'average_rating', 'review_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_average_rating(self, obj):
        reviews = obj.reviews.all()
        if not reviews:
            return 0
        return round(sum(review.rating for review in reviews) / len(reviews), 1)

    def get_review_count(self, obj):
        return obj.reviews.count()

class CartItemSerializer(serializers.ModelSerializer):
    meal = MealSerializer(read_only=True)
    meal_id = serializers.IntegerField(write_only=True)
    total_price = serializers.FloatField(read_only=True)
    id = serializers.IntegerField(read_only=True)

    class Meta:
        model = CartItem
        fields = ['id', 'meal', 'meal_id', 'quantity', 'total_price']
        read_only_fields = ['id', 'total_price']

    def validate_quantity(self, value):
        if value < 1:
            raise serializers.ValidationError('Quantity must be at least 1')
        return value

    def create(self, validated_data):
        user = self.context['request'].user
        meal_id = validated_data.pop('meal_id')
        
        try:
            meal = Meal.objects.get(id=meal_id)
        except Meal.DoesNotExist:
            raise serializers.ValidationError({'meal_id': 'Meal not found'})

        # Check if item already exists in cart
        cart_item = CartItem.objects.filter(user=user, meal=meal).first()
        if cart_item:
            cart_item.quantity = validated_data.get('quantity', cart_item.quantity + 1)
            cart_item.save()
            return cart_item

        return CartItem.objects.create(
            user=user,
            meal=meal,
            **validated_data
        )

    def update(self, instance, validated_data):
        instance.quantity = validated_data.get('quantity', instance.quantity)
        instance.save()
        return instance
