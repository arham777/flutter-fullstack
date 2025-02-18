from django.shortcuts import render, get_object_or_404
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from .serializers import SignUpSerializer, MealSerializer, ReviewSerializer, UserSerializer, CartItemSerializer
from .models import Meal, Review, CartItem

# Create your views here.

@api_view(['POST'])
def signup_view(request):
    serializer = SignUpSerializer(data=request.data)
    if serializer.is_valid():
        try:
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'token': str(refresh.access_token),
                'user': {
                    'username': user.username,
                    'email': user.email,
                    'is_admin': False
                }
            })
        except Exception as e:
            return Response(
                {'error': 'Username or email already exists'},
                status=status.HTTP_400_BAD_REQUEST
            )
    return Response(
        {'error': serializer.errors},
        status=status.HTTP_400_BAD_REQUEST
    )

@api_view(['POST'])
def signin_view(request):
    data = request.data
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return Response(
            {'error': 'Please provide both email and password'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response(
            {'error': 'Invalid email or password'},
            status=status.HTTP_401_UNAUTHORIZED
        )

    if not user.check_password(password):
        return Response(
            {'error': 'Invalid email or password'},
            status=status.HTTP_401_UNAUTHORIZED
        )

    if not user.is_active:
        return Response(
            {'error': 'This account has been deactivated'},
            status=status.HTTP_401_UNAUTHORIZED
        )

    refresh = RefreshToken.for_user(user)
    return Response({
        'token': str(refresh.access_token),
        'user': {
            'email': user.email,
            'username': user.username,
            'is_admin': user.username == 'admin'
        }
    })

class MealListCreateView(generics.ListCreateAPIView):
    queryset = Meal.objects.all()
    serializer_class = MealSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        if not self.request.user.username == 'admin':
            raise permissions.PermissionDenied("Only admin users can create meals")
        serializer.save()

class MealDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Meal.objects.all()
    serializer_class = MealSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_update(self, serializer):
        if not self.request.user.username == 'admin':
            raise permissions.PermissionDenied("Only admin users can update meals")
        serializer.save()

    def perform_destroy(self, instance):
        if not self.request.user.username == 'admin':
            raise permissions.PermissionDenied("Only admin users can delete meals")
        instance.delete()

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_review(request, meal_id):
    try:
        # Get the meal
        meal = get_object_or_404(Meal, pk=meal_id)
        
        # Check if user already reviewed this meal
        if Review.objects.filter(meal=meal, user=request.user).exists():
            return Response(
                {'error': 'You have already reviewed this meal'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create serializer with request data
        serializer = ReviewSerializer(data={
            'rating': request.data.get('rating'),
            'comment': request.data.get('comment')
        })
        
        if serializer.is_valid():
            # Save review with the meal and user
            review = serializer.save(meal=meal, user=request.user)
            
            # Return the updated meal data
            meal_data = MealSerializer(meal).data
            return Response(meal_data, status=status.HTTP_200_OK)
        
        return Response(
            {'error': serializer.errors},
            status=status.HTTP_400_BAD_REQUEST
        )
        
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_review(request, meal_id, review_id):
    # Get the review or return 404
    review = get_object_or_404(Review, id=review_id, meal_id=meal_id, user=request.user)
    
    # Create serializer with request data and instance
    serializer = ReviewSerializer(review, data=request.data, partial=True)
    
    if serializer.is_valid():
        # Save updated review
        serializer.save()
        
        # Return the updated meal data
        meal_data = MealSerializer(review.meal).data
        return Response(meal_data)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_review(request, meal_id, review_id):
    # Get the review or return 404
    review = get_object_or_404(Review, id=review_id, meal_id=meal_id, user=request.user)
    
    # Store meal reference before deletion
    meal = review.meal
    
    # Delete the review
    review.delete()
    
    # Return the updated meal data
    meal_data = MealSerializer(meal).data
    return Response(meal_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_users(request):
    if request.user.username != 'admin':
        return Response(
            {'error': 'Only admin can view users'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    users = User.objects.exclude(username='admin').order_by('date_joined')
    user_data = []
    
    for user in users:
        review_count = Review.objects.filter(user=user).count()
        last_login = user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else None
        date_joined = user.date_joined.strftime('%Y-%m-%d %H:%M:%S')
        
        user_data.append({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'is_active': user.is_active,
            'review_count': review_count,
            'last_login': last_login,
            'date_joined': date_joined,
        })
    
    return Response(user_data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_user_status(request, user_id):
    if request.user.username != 'admin':
        return Response(
            {'error': 'Only admin can modify users'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        user = User.objects.get(pk=user_id)
        if user.username == 'admin':
            return Response(
                {'error': 'Cannot modify admin user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user.is_active = not user.is_active
        user.save()
        
        return Response({
            'id': user.id,
            'username': user.username,
            'is_active': user.is_active
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_cart(request):
    """Get user's cart with all items"""
    try:
        cart_items = CartItem.objects.filter(user=request.user)
        serializer = CartItemSerializer(cart_items, many=True)
        
        total_amount = sum(item.total_price for item in cart_items)
        
        return Response({
            'items': serializer.data,
            'total_amount': total_amount
        })
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_to_cart(request):
    """Add item to cart or increment quantity if exists"""
    try:
        meal_id = request.data.get('meal_id')
        quantity = int(request.data.get('quantity', 1))

        if not meal_id:
            return Response(
                {'error': 'meal_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            meal = Meal.objects.get(id=meal_id)
        except Meal.DoesNotExist:
            return Response(
                {'error': 'Meal not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Get or create cart item
        cart_item, created = CartItem.objects.get_or_create(
            user=request.user,
            meal=meal,
            defaults={'quantity': quantity}
        )

        if not created:
            cart_item.quantity = quantity  # Use the provided quantity
            cart_item.save()

        serializer = CartItemSerializer(cart_item)
        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )

    except ValueError as e:
        return Response(
            {'error': 'Invalid quantity value'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def remove_from_cart(request, item_id):
    """Remove item from cart"""
    try:
        try:
            cart_item = CartItem.objects.get(
                id=item_id,
                user=request.user
            )
        except CartItem.DoesNotExist:
            return Response(
                {'error': 'Cart item not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        cart_item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_cart_item(request, item_id):
    """Update quantity of cart item"""
    try:
        try:
            cart_item = CartItem.objects.get(
                id=item_id,
                user=request.user
            )
        except CartItem.DoesNotExist:
            return Response(
                {'error': 'Cart item not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        quantity = request.data.get('quantity')
        if quantity is None:
            return Response(
                {'error': 'quantity is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            quantity = int(quantity)
        except ValueError:
            return Response(
                {'error': 'quantity must be a number'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if quantity < 0:
            return Response(
                {'error': 'quantity must be positive'},
                status=status.HTTP_400_BAD_REQUEST
            )
        elif quantity == 0:
            cart_item.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            cart_item.quantity = quantity
            cart_item.save()
            serializer = CartItemSerializer(cart_item)
            return Response(serializer.data)

    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clear_cart(request):
    """Clear all items from user's cart"""
    try:
        CartItem.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
